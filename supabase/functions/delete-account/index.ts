// =============================================================================
// delete-account — suppression de compte demandée depuis une app Amana
//
// Appelée par les apps client, livreur et partenaire via
// supabase.functions.invoke('delete-account', body: {confirm, app}).
//
// Vérifie, dans cet ordre :
//   1. le JWT (l'utilisateur est bien celui qu'il prétend) ;
//   2. le mot de confirmation « SUPPRIMER » ;
//   3. une ré-authentification RÉCENTE : la dernière entrée du claim `amr`
//      (mot de passe, Google...) doit dater de moins de 5 minutes. L'app
//      reconnecte la personne juste avant l'appel. Sans ça, un téléphone
//      laissé déverrouillé suffirait à supprimer le compte.
//
// Puis, avec la clé service_role :
//   4. account_deletion_execute() : re-vérifie les blocages, efface les
//      données personnelles, anonymise, bannit, journalise (une transaction) ;
//   5. suppression « soft » GoTrue : email illisible, identités et sessions
//      supprimées. La ligne auth.users reste, donc aucune clé étrangère ne se
//      déclenche : commandes, règlements et bons colis restent intacts ;
//   6. retrait du Stockage (non transactionnel) des fichiers que la fonction
//      SQL a listés : photo de profil, photos de facture, messages vocaux.
//      Les preuves de remise colis restent 30 jours : c'est la purge
//      planifiée (purge-colis-proofs) qui les retire.
//
// Si l'étape 5 échoue, la personne est déjà bannie et anonymisée par
// l'étape 4 : elle ne peut plus se connecter. Le journal reste en
// 'auth_pending' avec l'erreur, pour que l'admin relance.
//
// Réponses :
//   200 {status: 'deleted'}
//   409 {status: 'blocked', blockers: [{code, count?, amount?}]}
//   400 {error: 'confirm_mismatch' | 'bad_app' | 'bad_request'}
//   401 {error: 'not_authenticated'}
//   403 {error: 'reauth_required'}
//   500 {error: 'failed'}
//
// Secrets : SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY, fournis par la
// plateforme.
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CONFIRM_WORD = "SUPPRIMER";
const REAUTH_MAX_AGE_S = 5 * 60;
const APPS = new Set(["client", "driver", "partner"]);
// Bucket par défaut de chaque sorte de fichier listée par
// account_deletion_execute, quand la base garde un chemin et non une URL.
// Une URL n'est suivie que vers ces mêmes buckets : rien d'autre ne peut
// être retiré d'ici (le logo d'une boutique n'est jamais listé).
const FILE_BUCKETS: Record<string, string> = {
  avatar: "profiles",
  bill_photo: "package-photos",
  voice_note: "voice-messages",
};
const ALLOWED_BUCKETS = new Set(["profiles", "avatars", "package-photos", "voice-messages"]);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** Charge utile du JWT. Sa signature a déjà été vérifiée par getUser(). */
function jwtPayload(token: string): Record<string, unknown> | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/")
      .padEnd(Math.ceil(part.length / 4) * 4, "=");
    return JSON.parse(atob(b64));
  } catch {
    return null;
  }
}

/** Date (en secondes) de la connexion la plus récente, d'après `amr`. */
function lastAuthAt(payload: Record<string, unknown>): number | null {
  const amr = payload["amr"];
  if (!Array.isArray(amr)) return null;
  let last: number | null = null;
  for (const entry of amr) {
    const ts = (entry as { timestamp?: unknown })?.timestamp;
    if (typeof ts === "number" && (last === null || ts > last)) last = ts;
  }
  return last;
}

/**
 * bucket + chemin d'un fichier listé par la base : URL de NOTRE Stockage
 * (publique ou signée), ou chemin nu dans le bucket par défaut de sa sorte.
 * null pour tout le reste (autre domaine, bucket non autorisé).
 */
function storageObject(ref: string, kind: string): { bucket: string; path: string } | null {
  const base = `${SUPABASE_URL}/storage/v1/object/`;
  if (/^https?:\/\//i.test(ref)) {
    if (!ref.startsWith(base)) return null;
    const rest = decodeURIComponent(ref.slice(base.length).split("?")[0])
      .replace(/^(public|sign|authenticated)\//, "");
    const slash = rest.indexOf("/");
    if (slash <= 0) return null;
    const bucket = rest.slice(0, slash);
    const path = rest.slice(slash + 1);
    return ALLOWED_BUCKETS.has(bucket) && path ? { bucket, path } : null;
  }
  const bucket = FILE_BUCKETS[kind];
  const path = ref.replace(/^\/+/, "");
  return bucket && path ? { bucket, path } : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "bad_request" }, 405);

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error("delete-account: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY absents");
    return json({ error: "failed" }, 500);
  }

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "not_authenticated" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Qui appelle. La clé anon est aussi un JWT valide : getUser() la refuse.
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData?.user;
  if (userError || !user) return json({ error: "not_authenticated" }, 401);

  // 2. Confirmation explicite.
  let body: { confirm?: unknown; app?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  if (typeof body.confirm !== "string" || body.confirm.trim() !== CONFIRM_WORD) {
    return json({ error: "confirm_mismatch" }, 400);
  }
  const app = typeof body.app === "string" ? body.app : "";
  if (!APPS.has(app)) return json({ error: "bad_app" }, 400);

  // 3. Ré-authentification récente.
  const payload = jwtPayload(token);
  const authAt = payload && payload["sub"] === user.id ? lastAuthAt(payload) : null;
  const now = Math.floor(Date.now() / 1000);
  if (authAt === null || now - authAt > REAUTH_MAX_AGE_S) {
    return json({ error: "reauth_required" }, 403);
  }

  // 4. Blocages, anonymisation, bannissement, journal.
  const { data: result, error: rpcError } = await admin.rpc(
    "account_deletion_execute",
    { p_uid: user.id, p_app: app },
  );
  if (rpcError || !result) {
    console.error("delete-account: account_deletion_execute", rpcError?.message);
    return json({ error: "failed" }, 500);
  }

  if (result.status === "blocked") {
    return json({ status: "blocked", blockers: result.blockers ?? [] }, 409);
  }

  // 5. Suppression soft GoTrue. Rejouée aussi sur 'already_deleted' : un
  //    premier appel a pu s'arrêter entre l'étape 4 et celle-ci.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id, true);
  const logId = typeof result.log_id === "string" ? result.log_id : null;
  if (logId) {
    const update = deleteError
      ? { error: `gotrue: ${deleteError.message}`.slice(0, 500) }
      : { status: "completed", completed_at: new Date().toISOString() };
    const { error: logError } = await admin
      .from("account_deletions")
      .update(update)
      .eq("id", logId);
    if (logError) console.error("delete-account: journal", logError.message);
  }
  if (deleteError) {
    // Pas un échec pour la personne : elle est bannie et anonymisée.
    console.error("delete-account: suppression GoTrue", deleteError.message);
  }

  // 6. Fichiers personnels : regroupés par bucket, un appel par bucket.
  const byBucket = new Map<string, string[]>();
  for (const f of Array.isArray(result.files) ? result.files : []) {
    if (typeof f?.ref !== "string" || typeof f?.kind !== "string") continue;
    const obj = storageObject(f.ref, f.kind);
    if (!obj) continue;
    byBucket.set(obj.bucket, [...(byBucket.get(obj.bucket) ?? []), obj.path]);
  }
  for (const [bucket, paths] of byBucket) {
    const { error: storageError } = await admin.storage.from(bucket).remove(paths);
    // Pas un échec pour la personne : les colonnes qui pointaient vers ces
    // fichiers sont déjà vidées. Le journal garde la trace pour l'admin.
    if (storageError) {
      console.error("delete-account: stockage", bucket, storageError.message);
      if (logId) {
        await admin.from("account_deletions")
          .update({ error: `storage ${bucket}: ${storageError.message}`.slice(0, 500) })
          .eq("id", logId);
      }
    }
  }

  return json({ status: "deleted" });
});
