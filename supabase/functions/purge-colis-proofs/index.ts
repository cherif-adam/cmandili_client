// =============================================================================
// purge-colis-proofs — effacement des preuves colis des comptes supprimés
//
// Règle : la preuve de remise d'un colis (photos, GPS, plaque, nom du
// livreur, CIN) reste 30 jours après la dernière commande terminée de la
// personne supprimée, puis elle est effacée. Voir la section 7 de
// supabase/migrations/20261017090000_account_deletion.sql.
//
// Appelée chaque nuit par pg_cron (supabase/scripts/
// 20261022_schedule_colis_proof_purge.sql), jamais par une app.
//
// En deux temps, parce que le Stockage n'est pas transactionnel :
//   1. account_deletion_due_proofs() : les suppressions arrivées à échéance
//      et leurs fichiers (photos de prise en charge et de remise, photo du
//      colis) ;
//   2. retrait de ces fichiers du Stockage ;
//   3. account_deletion_purge_proofs(ids) : effacement des colonnes, pour les
//      seules suppressions dont TOUS les fichiers ont été retirés. Les autres
//      restent dues : la nuit suivante réessaie.
//
// Accès : verify_jwt (config.toml) PLUS un secret partagé dans l'en-tête
// x-cron-secret, égal au secret PURGE_CRON_SECRET de la fonction. Le JWT
// seul ne suffit pas : la clé anon, publique, en est un.
//
// Réponses :
//   200 {due, purged, failed}
//   401 {error: 'forbidden'}
//   500 {error: 'failed'}
// =============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CRON_SECRET = Deno.env.get("PURGE_CRON_SECRET") ?? "";

// Bucket de chaque sorte de fichier quand la base garde un chemin nu. Une URL
// n'est suivie que vers ces mêmes buckets.
const FILE_BUCKETS: Record<string, string> = {
  colis_proof: "colis-proofs",
  package_photo: "package-photos",
};
const ALLOWED_BUCKETS = new Set(["colis-proofs", "package-photos"]);

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

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "forbidden" }, 405);

  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !CRON_SECRET) {
    console.error("purge-colis-proofs: SUPABASE_URL / SERVICE_ROLE_KEY / PURGE_CRON_SECRET absents");
    return json({ error: "failed" }, 500);
  }
  if (!sameSecret(req.headers.get("x-cron-secret") ?? "", CRON_SECRET)) {
    return json({ error: "forbidden" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 1. Ce qui est dû.
  const { data: due, error: dueError } = await admin.rpc("account_deletion_due_proofs");
  if (dueError) {
    console.error("purge-colis-proofs: due", dueError.message);
    return json({ error: "failed" }, 500);
  }
  const deletions: DueDeletion[] = Array.isArray(due) ? due : [];

  // 2. Fichiers, suppression par suppression : une erreur de Stockage ne
  //    bloque que la suppression concernée.
  const ready: string[] = [];
  let failed = 0;
  for (const d of deletions) {
    const byBucket = new Map<string, string[]>();
    let unreadable = false;
    for (const f of d.files ?? []) {
      const obj = typeof f?.ref === "string" ? storageObject(f.ref, f.kind) : null;
      if (!obj) {
        // Une référence qu'on ne sait pas retirer ne doit pas disparaître de
        // la base en laissant le fichier derrière elle.
        console.error("purge-colis-proofs: référence illisible", d.deletion_id, f?.kind);
        unreadable = true;
        continue;
      }
      byBucket.set(obj.bucket, [...(byBucket.get(obj.bucket) ?? []), obj.path]);
    }
    let ok = !unreadable;
    for (const [bucket, paths] of byBucket) {
      const { error } = await admin.storage.from(bucket).remove(paths);
      if (error) {
        console.error("purge-colis-proofs: stockage", d.deletion_id, bucket, error.message);
        ok = false;
      }
    }
    if (ok) ready.push(d.deletion_id);
    else failed++;
  }

  // 3. Colonnes.
  let purged = 0;
  if (ready.length > 0) {
    const { data: n, error: purgeError } = await admin.rpc(
      "account_deletion_purge_proofs",
      { p_deletion_ids: ready },
    );
    if (purgeError) {
      console.error("purge-colis-proofs: purge", purgeError.message);
      return json({ error: "failed" }, 500);
    }
    purged = typeof n === "number" ? n : 0;
  }

  return json({ due: deletions.length, purged, failed });
});
