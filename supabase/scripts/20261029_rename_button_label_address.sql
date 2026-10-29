-- ============================================================================
-- CMANDILI / Amana — Renommer l'adresse enregistrée sous le texte d'un bouton
--
-- À lancer dans le SQL Editor (projet cmandili). Ne supprime rien.
--
-- Une adresse s'appelait « Ajouter une nouvelle adresse » : la carte renvoyait
-- le point choisi avec son propre titre comme nom, et la fenêtre « Adresses
-- enregistrées » du profil en pré-remplissait le champ nom (corrigé dans
-- l'app, commit 548f5e6). Une seule ligne sur le live au 29/10 :
--   f9c7f6be-670b-43d2-8665-a3e4d303e64e  « Ajouter une nouvelle adresse »
--   W8M2+932, Kondar, Tunisie  (pas l'adresse par défaut)
-- Elle prend le nom de sa localité, « Kondar » ; le client peut la renommer.
-- Pour un autre nom, changez-le dans l'UPDATE ci-dessous.
--
-- Rejouable : relancé, il ne trouve plus rien à renommer et s'arrête.
-- ============================================================================

begin;

do $check$
declare n integer;
begin
  select count(*) into n from public.user_addresses
   where id = 'f9c7f6be-670b-43d2-8665-a3e4d303e64e'
     and name = 'Ajouter une nouvelle adresse';
  if n <> 1 then
    raise exception 'Adresse à renommer introuvable (% ligne) : rien n''est changé', n;
  end if;
end
$check$;

update public.user_addresses
   set name = 'Kondar'
 where id = 'f9c7f6be-670b-43d2-8665-a3e4d303e64e'
   and name = 'Ajouter une nouvelle adresse';

commit;

-- ── Vérification ───────────────────────────────────────────────────────────
-- Attendu : nouveau_nom = Kondar ; noms_de_bouton_restants = 0.
select (select name from public.user_addresses
         where id = 'f9c7f6be-670b-43d2-8665-a3e4d303e64e') as nouveau_nom,
       (select count(*) from public.user_addresses
         where name in ('Ajouter une nouvelle adresse', 'Add New Address', 'إضافة عنوان جديد',
                        'Choisir sur la carte', 'Choose on the map', 'اختر من الخريطة')) as noms_de_bouton_restants;
