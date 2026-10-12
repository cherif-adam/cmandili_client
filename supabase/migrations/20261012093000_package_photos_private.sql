-- ============================================================================
-- CMANDILI — `package-photos` passe en privé
--
-- NON EXÉCUTÉ. À LANCER APRÈS le déploiement des nouveaux builds livreur et
-- client, pas avant.
--
-- POURQUOI SÉPARÉE DE 20261012090000 : le bucket a été créé public en juin
-- (20260623_courier_photo_and_saved_recipients) et les apps lisent ces images
-- par `getPublicUrl`. Le basculer en privé coupe l'affichage des photos de
-- colis dans tout APK déjà installé. Le faire au même moment que la mise en
-- place du bon de prise en charge punirait des livreurs qui n'ont encore rien
-- à se reprocher. Donc : builds d'abord, ce fichier ensuite.
--
-- CE QUE ÇA CORRIGE : aujourd'hui une photo de colis est lisible par
-- quiconque connaît son URL, sans authentification. L'URL contient un
-- identifiant utilisateur et un horodatage — c'est devinable, et de toute
-- façon elle circule en clair dans les réponses de l'API.
--
-- APRÈS CE FICHIER, les apps doivent servir ces images par URL signée
-- (`createSignedUrl`), jamais par `getPublicUrl`.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================

begin;

update storage.buckets set public = false where id = 'package-photos';

-- La lecture publique historique disparaît. Le chemin est `<user_id>/<ts>.jpg`
-- (voir courier_screen.dart), donc le premier segment identifie l'expéditeur.
drop policy if exists package_photos_read on storage.objects;
drop policy if exists package_photos_read_scoped on storage.objects;

create policy package_photos_read_scoped
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'package-photos'
    and (
      -- L'expéditeur, sur ses propres photos.
      split_part(name, '/', 1) = auth.uid()::text
      -- Le livreur assigné à une commande portant cette photo. Volontairement
      -- restreint à SA commande : un livreur n'a pas à parcourir le bucket.
      or exists (
        select 1
          from public.orders o
          join public.drivers d on d.id = o.driver_id
         where d.user_id = auth.uid()
           and o.package_photo_url like '%' || name
      )
      or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
    )
  );

-- ── Garde-fou avant COMMIT ─────────────────────────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from storage.buckets
   where id = 'package-photos' and public;
  if n <> 0 then
    raise exception 'Abandon : package-photos est encore public';
  end if;

  select count(*) into n from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname = 'package_photos_read_scoped';
  if n <> 1 then
    raise exception 'Abandon : la policy de lecture restreinte est absente';
  end if;

  -- Plus aucune policy ne doit ouvrir ce bucket a tout le monde.
  select count(*) into n from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and qual like '%package-photos%'
     and qual not like '%auth.uid()%';
  if n <> 0 then
    raise exception 'Abandon : % policy(s) laissent package-photos ouvert', n;
  end if;
end
$$;

commit;
