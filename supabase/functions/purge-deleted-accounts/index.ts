// =============================================================================
// purge-deleted-accounts — purges différées des comptes supprimés
//
// Deux règles, voir les sections 7 et 8 de
// supabase/migrations/20261017090000_account_deletion.sql :
//   • preuves colis (photos, GPS, plaque, nom du livreur, CIN) : effacées 30
//     jours après la dernière commande terminée de la personne supprimée ;
//   • dossier d'identité d'un livreur supprimé (CIN, contrat) : effacé 5 ans
//     après sa dernière livraison.
//
// Appelée chaque nuit par pg_cron (supabase/scripts/
// 20261022_schedule_account_purge.sql), jamais par une app.
//
// Pour chaque règle, en deux temps, parce que le Stockage n'est pas
// transactionnel :
//   1. la base liste les suppressions arrivées à échéance et leurs fichiers ;
//   2. ces fichiers sont retirés du Stockage ;
//   3. la base efface, pour les seules suppressions dont TOUS les fichiers ont
//      été retirés. Les autres restent dues : la nuit suivante réessaie.
//
// Accès : verify_jwt (config.toml) PLUS un secret partagé dans l'en-tête
// x-cron-secret, égal au secret PURGE_CRON_SECRET de la fonction. Le JWT
// seul ne suffit pas : la clé anon, publique, en est un.
//
// Réponses :
//   200 {proofs: {due, purged, failed}, identities: {due, purged, failed}}
//   401 {error: 'forbidden'}
//   500 {error: 'failed'}
// =============================================================================

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("PURGE_CRON_SECRET") ?? "";

// Bucket de chaque sorte de fichier quand la base garde un chemin nu. Une URL
// n'est suivie que vers ces mêmes buckets.
const FILE_BUCKETS: Record<string, string> = {
  colis_proof: "colis-proofs",
  package_photo: "package-photos",
  driver_contract: "driver-contracts",
};
const ALLOWED_BUCKETS = new Set(["colis-proofs", "package-photos", "driver-contracts"]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Comparaison en temps constant : le secret ne fuit pas par la durée. */
function sameSecret(a: string, b: string): boolean {
  if (!a || !b || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** bucket + chemin d'un fichier listé par la base, sinon null. */
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

type DueDeletion = { deletion_id: string; files: { kind: string; ref: string }[] };
type Outcome = { due: number; purged: number; failed: number };

/**
 * Une règle de purge : `dueFn` liste ce qui est dû, les fichiers sont
 * retirés, puis `purgeFn` efface en base ce dont les fichiers sont partis.
 */
async function runPurge(
  admin: SupabaseClient,
  dueFn: string,
  purgeFn: string,
): Promise<Outcome> {
  const { data: due, error: dueError } = await admin.rpc(dueFn);
  if (dueError) throw new Error(`${dueFn}: ${dueError.message}`);
  const deletions: DueDeletion[] = Array.isArray(due) ? due : [];

  const ready: string[] = [];
  let failed = 0;
  for (const d of deletions) {
    const byBucket = new Map<string, string[]>();
    let ok = true;
    for (const f of d.files ?? []) {
      const obj = typeof f?.ref === "string" ? storageObject(f.ref, f.kind) : null;
      if (!obj) {
        // Une référence qu'on ne sait pas retirer ne doit pas disparaître de
        // la base en laissant le fichier derrière elle.
        console.error(`${purgeFn}: référence illisible`, d.deletion_id, f?.kind);
        ok = false;
        continue;
      }
      byBucket.set(obj.bucket, [...(byBucket.get(obj.bucket) ?? []), obj.path]);
    }
    for (const [bucket, paths] of byBucket) {
      const { error } = await admin.storage.from(bucket).remove(paths);
      if (error) {
        console.error(`${purgeFn}: stockage`, d.deletion_id, bucket, error.message);
        ok = false;
      }
    }
    if (ok) ready.push(d.deletion_id);
    else failed++;
  }

  let purged = 0;
  if (ready.length > 0) {
    const { data: n, error: purgeError } = await admin.rpc(purgeFn, { p_deletion_ids: ready });
    if (purgeError) throw new Error(`${purgeFn}: ${purgeError.message}`);
    purged = typeof n === "number" ? n : 0;
  }
  return { due: deletions.length, purged, failed };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "forbidden" }, 405);

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !CRON_SECRET) {
    console.error("purge-deleted-accounts: SUPABASE_URL / SERVICE_ROLE_KEY / PURGE_CRON_SECRET absents");
    return json({ error: "failed" }, 500);
  }
  if (!sameSecret(req.headers.get("x-cron-secret") ?? "", CRON_SECRET)) {
    return json({ error: "forbidden" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    // Indépendantes : un échec de l'une n'empêche pas l'autre de tourner.
    const [proofs, identities] = await Promise.allSettled([
      runPurge(admin, "account_deletion_due_proofs", "account_deletion_purge_proofs"),
      runPurge(admin, "account_deletion_due_identities", "account_deletion_purge_identities"),
    ]);
    for (const r of [proofs, identities]) {
      if (r.status === "rejected") console.error("purge-deleted-accounts:", String(r.reason));
    }
    if (proofs.status === "rejected" && identities.status === "rejected") {
      return json({ error: "failed" }, 500);
    }
    return json({
      proofs: proofs.status === "fulfilled" ? proofs.value : null,
      identities: identities.status === "fulfilled" ? identities.value : null,
    });
  } catch (e) {
    console.error("purge-deleted-accounts:", String(e));
    return json({ error: "failed" }, 500);
  }
});
