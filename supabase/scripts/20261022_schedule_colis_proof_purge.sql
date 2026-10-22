-- ============================================================================
-- CMANDILI / Amana — Planifier la purge des preuves colis (comptes supprimés)
--
-- NE FAIT PARTIE D'AUCUNE MIGRATION. À lancer à la main, dans le SQL Editor,
-- UNE FOIS que :
--   1. la migration 20261017090000_account_deletion.sql est appliquée ;
--   2. la fonction est déployée :
--        supabase functions deploy purge-colis-proofs
--   3. un secret aléatoire est posé des DEUX côtés, avec la même valeur :
--        supabase secrets set PURGE_CRON_SECRET=<valeur>
--        select vault.create_secret('<valeur>', 'purge_cron_secret');
--
-- Chaque nuit à 03:17 (UTC), pg_cron appelle la fonction, qui efface les
-- preuves arrivées à échéance (30 jours après la dernière commande terminée
-- de la personne supprimée). Idempotent : relancer ce script remplace la
-- planification existante.
--
-- Pour arrêter : select cron.unschedule('account_deletion_purge_colis_proofs');
-- ============================================================================

do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name = 'purge_cron_secret') then
    raise exception 'Le secret purge_cron_secret est absent du Vault (étape 3 de l''en-tête).';
  end if;
end
$$;

select cron.unschedule(jobid)
  from cron.job
 where jobname = 'account_deletion_purge_colis_proofs';

-- Authorization : même clé que les triggers existants (app.edge_function_secret,
-- repli sur la clé publishable), pour passer verify_jwt. La vraie garde est
-- x-cron-secret, lu dans le Vault au moment de l'appel.
select cron.schedule(
  'account_deletion_purge_colis_proofs',
  '17 3 * * *',
  $cron$
    select net.http_post(
      url     := 'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/purge-colis-proofs',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || coalesce(
          current_setting('app.edge_function_secret', true),
          'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
        ),
        'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'purge_cron_secret')
      ),
      body    := '{}'::jsonb
    );
  $cron$
);
