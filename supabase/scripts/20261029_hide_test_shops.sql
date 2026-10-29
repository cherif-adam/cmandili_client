-- ============================================================================
-- CMANDILI / Amana — Retirer de l'app client les 2 boutiques de test
--
-- À lancer dans le SQL Editor (projet cmandili). Ne supprime rien.
--
--   « restaurant »  vendors 2a955c08-3a5f-43ba-82c4-8c4318c0d44f
--                   partenaire restauu2@gmail.com, 21 plats, 1 commande
--                   (annulée le 16/09, 3 articles), portefeuille 50 DT
--   « food »        vendors e523742d-37fc-4ee8-b846-b114e0332e7f
--                   partenaire food1@gmail.com, 20 plats, aucune commande,
--                   portefeuille 50 DT
-- Aucun règlement, avis, promo ni favori sur l'une ou l'autre ; les deux
-- comptes ne servent à rien d'autre (dernière connexion le 20/05).
--
-- MASQUER, PAS SUPPRIMER. « restaurant » a une commande et les deux comptes
-- ont un portefeuille : supprimer casserait l'historique ou laisserait un
-- compte partenaire pointer vers une boutique absente. Masquer se défait en
-- une ligne (deleted_at = null, is_open = true).
--
-- Ce que ça change, sur ces 2 lignes de vendors seulement :
--   deleted_at = now()  → plus dans les vues restaurants / food_items, plus
--                         lues par la policy vendors_read (sauf pour le client
--                         qui avait commandé là, dans son historique), et le
--                         trigger enforce_venue_open refuse toute commande
--   is_open = false     → fermées, même si on les réaffichait
-- Rien d'autre : ni partners, ni comptes, ni portefeuilles, ni plats, ni la
-- commande, ni l'image du bucket items.
-- ============================================================================

begin;

do $check$
declare n integer;
begin
  -- Les 2 boutiques, par identifiant complet ET par nom : sinon rien ne bouge.
  select count(*) into n
    from public.vendors v
    join public.partners p on p.entity_id = v.id
   where (v.id = '2a955c08-3a5f-43ba-82c4-8c4318c0d44f' and p.business_name = 'restaurant' and v.name = 'restaurant')
      or (v.id = 'e523742d-37fc-4ee8-b846-b114e0332e7f' and p.business_name = 'food' and v.name = 'food');
  if n <> 2 then
    raise exception 'Attendu les 2 boutiques de test, trouvé % : rien n''est changé', n;
  end if;
end
$check$;

-- Le nombre des AUTRES boutiques visibles avant, pour la vérification.
select set_config('test_shops.others_before',
         (select count(*) from public.vendors
           where deleted_at is null
             and id not in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f'))::text,
         false);

update public.vendors
   set deleted_at = now(),
       is_open = false
 where id in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f');

commit;

-- ── Vérification ───────────────────────────────────────────────────────────
-- Attendu : visibles_clients = 0, plats_visibles = 0, ouvertes = 0,
--           autres_avant = autres_apres (18 au 29/10).
select (select count(*) from public.restaurants
         where id in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f')) as visibles_clients,
       (select count(*) from public.food_items
         where restaurant_id in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f')) as plats_visibles,
       (select count(*) from public.vendors
         where id in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f') and is_open) as ouvertes,
       nullif(current_setting('test_shops.others_before', true), '')::int as autres_avant,
       (select count(*) from public.vendors
         where deleted_at is null
           and id not in ('2a955c08-3a5f-43ba-82c4-8c4318c0d44f', 'e523742d-37fc-4ee8-b846-b114e0332e7f')) as autres_apres;
