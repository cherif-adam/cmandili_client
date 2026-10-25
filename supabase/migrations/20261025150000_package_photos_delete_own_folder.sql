-- ============================================================================
-- CMANDILI / Amana — package-photos : on ne supprime que SES photos
--
-- NON EXÉCUTÉE. À lancer dans le SQL Editor du dashboard (voir plus bas).
--
-- PROBLÈME (constaté sur le live le 25/10/2026, par SELECT sur pg_policies) :
-- la policy package_photos_delete_own, créée par
-- 20260623_courier_photo_and_saved_recipients.sql, autorise
--     bucket_id = 'package-photos' AND auth.uid() IS NOT NULL
-- c'est-à-dire : TOUT compte connecté peut supprimer N'IMPORTE QUELLE photo du
-- bucket — photos de colis et photos de factures des autres clients.
--
-- CORRECTION : on ne peut supprimer un fichier que s'il est dans SON dossier
-- (le chemin commence par son identifiant) ET que c'est lui qui l'a déposé
-- (owner_id). Les apps rangent toujours les photos sous `<user_id>/...`
-- (lib/core/data/package_photo_storage.dart : uploadParcelPhoto et
-- uploadBillPhoto) ; sur le live, les 25 fichiers du bucket respectent les
-- deux conditions.
--
-- CE QUI NE CHANGE PAS :
--   • les apps d'adam-branch ne suppriment jamais dans ce bucket ;
--   • les Edge Functions delete-account et purge-deleted-accounts utilisent la
--     clé service_role, qui ne passe pas par ces policies ;
--   • l'ancien build client de Firas (1.0.2+5) ne supprime que dans le dossier
--     de la personne connectée : il reste autorisé.
-- La lecture publique et le dépôt (INSERT) ne sont pas touchés ici : la
-- lecture est traitée par 20261012093000_package_photos_private.sql (à lancer
-- après les nouveaux builds), le dépôt reste ouvert à tout compte connecté.
--
-- OÙ LA LANCER : dans le SQL Editor du dashboard Supabase. Les policies de
-- storage.objects existantes y ont été créées (rôle supabase_admin d'après
-- pg_stat_statements). Le rôle de connexion de la CLI n'est pas membre de
-- supabase_storage_admin, propriétaire de la table : il pourrait être refusé.
--
-- Rejouable : supprime puis recrée la policy, sous le même nom.
-- ============================================================================

begin;

drop policy if exists package_photos_delete_own on storage.objects;

do $$
begin
  if not exists (
    select 1 from pg_policies
     where schemaname = 'storage'
       and tablename  = 'objects'
       and policyname = 'package_photos_delete_own'
  ) then
    execute $p$
      create policy package_photos_delete_own
        on storage.objects for delete
        to authenticated
        using (
          bucket_id = 'package-photos'
          and (storage.foldername(name))[1] = (select auth.uid())::text
          and owner_id = (select auth.uid())::text
        )
    $p$;
  end if;
end
$$;

commit;


-- ── Vérification (à lire après l'exécution) ────────────────────────────────
-- Attendu : UNE ligne, policy_ok = true, et delete_policies_on_bucket = 1
-- (aucune autre policy DELETE ou ALL ne vise encore package-photos).
select policyname,
       cmd,
       roles,
       qual,
       (cmd = 'DELETE'
        and roles = '{authenticated}'::name[]
        and qual like '%foldername%'
        and qual like '%owner_id%'
        and qual like '%auth.uid()%') as policy_ok,
       (select count(*)
          from pg_policies
         where schemaname = 'storage'
           and tablename  = 'objects'
           and cmd in ('DELETE', 'ALL')
           and coalesce(qual, '') like '%package-photos%') as delete_policies_on_bucket
  from pg_policies
 where schemaname = 'storage'
   and tablename  = 'objects'
   and policyname = 'package_photos_delete_own';
