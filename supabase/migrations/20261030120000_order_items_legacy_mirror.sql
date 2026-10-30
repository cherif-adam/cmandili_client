-- ============================================================================
-- CMANDILI / Amana — Les nouveaux articles peuvent être commandés
--
-- À lancer dans le SQL Editor (projet cmandili), puis
-- `supabase migration repair --status applied 20261030120000`.
--
-- ── CONSTAT (live, 30/10) ──────────────────────────────────────────────────
-- « Commander » chez Charlot : order_items_food_item_id_fkey refuse la ligne,
-- « Key is not present in table food_items_legacy ». Les articles vivent dans
-- vendor_items depuis 20260922010000 (« phase 1 de 2 ») ; les clés étrangères
-- de order_items pointent encore vers les copies *_legacy, figées ce jour-là,
-- et la phase 2 n'a jamais été faite. Charlot (créé le 25/09) n'a ni sa ligne
-- dans restaurants_legacy ni ses 18 plats dans food_items_legacy : chaque
-- commande chez lui échouait. Les autres boutiques passaient parce que leurs
-- articles existaient encore dans la copie ; tout article ajouté depuis le
-- 22/09 aurait échoué de même (plats -> food_items_legacy, produits de
-- supermarché -> grocery_items_legacy). Les boutiques (fleurs, pâtisserie...)
-- utilisent vendor_item_id -> vendor_items : jamais touchées.
-- Même cause : Charlot ne peut pas être mis en favori (user_favorites ->
-- restaurants_legacy).
--
-- ── POURQUOI NE PAS REPOINTER LES CLÉS ──────────────────────────────────────
-- Les 3 apps chargent les commandes avec
--   order_items(*, food_items:food_items_legacy(*), grocery_items:grocery_items_legacy(*), vendor_items(*))
-- (client order_row_mapper, livreur order_offer_dialog / driver_orders_provider,
-- partenaire partner_order_repository), et les favoris avec
-- restaurants:restaurants_legacy(*). PostgREST résout ces jointures par les
-- clés étrangères : les pointer vers vendor_items, ou les supprimer, casserait
-- ces écrans, versions déjà installées comprises.
--
-- ── CE QUE FAIT CE FICHIER ──────────────────────────────────────────────────
-- La copie *_legacy redevient complète, et le reste :
--   1. Le trigger auto_apply_customization_template de food_items_legacy est
--      coupé. Il ajoutait d'office aux plats « makloub, mlawi, baguette
--      farcie, calzone... » les groupes Sauce / Garniture / Suppléments
--      (Gruyère 6 DT, Cheddar 3,6 DT...) et des variantes plus chères. Plus
--      rien n'entrant dans la copie depuis le 22/09, il ne tournait plus ; le
--      recopiage l'aurait réveillé pour chaque nouveau plat, sans que personne
--      l'ait décidé. Le rallumer est une décision produit :
--        alter table public.food_items_legacy enable trigger auto_apply_customization_template;
--   2. Trigger AFTER INSERT sur vendor_items : un nouveau plat (boutique
--      'food') ou produit ('grocery') est recopié avec le même id, sa boutique
--      aussi si elle manque. Les autres catégories ne sont pas concernées.
--   3. Rattrapage : les boutiques et articles déjà absents de la copie
--      (au 30/10 : Charlot et ses 18 plats, aucun ne relevant du modèle) y
--      sont ajoutés.
-- Les clés étrangères restent : une ligne qui désigne un article inexistant
-- est toujours refusée. Rien n'est supprimé ; les copies existantes ne sont
-- pas réécrites.
-- La vraie phase 2 (requêtes des apps via vendor_items, puis clés repointées
-- et tables *_legacy supprimées) demande une nouvelle version des 3 apps.
-- ============================================================================


-- ── 1. Le modèle de personnalisation ne se déclenche plus tout seul ─────────
do $template$
begin
  if exists (select 1 from pg_trigger where tgrelid = 'public.food_items_legacy'::regclass
                and tgname = 'auto_apply_customization_template') then
    alter table public.food_items_legacy disable trigger auto_apply_customization_template;
  end if;
end
$template$;


-- ── 2. Recopier un article (et sa boutique) dans la copie *_legacy ─────────
create or replace function public.mirror_vendor_item_to_legacy_by_id(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  it public.vendor_items%rowtype;
  v  public.vendors%rowtype;
begin
  select * into it from public.vendor_items where id = p_item_id;
  if it.id is null then
    return;
  end if;
  select * into v from public.vendors where id = it.vendor_id;
  if v.id is null then
    return;
  end if;

  if v.category = 'food' then
    insert into public.restaurants_legacy (id, name, description, image_url, rating, review_count,
                                           delivery_time_min, delivery_fee, min_order, is_open, latitude,
                                           longitude, categories, created_at, is_ghost_restaurant,
                                           auto_close_enabled, opening_time, closing_time)
    values (v.id, v.name, v.description, v.image_url, v.rating, v.review_count, v.delivery_time_min,
            v.delivery_fee, v.min_order, v.is_open, v.latitude, v.longitude, v.categories, v.created_at,
            v.is_ghost_restaurant, v.auto_close_enabled, v.opening_time, v.closing_time)
    on conflict (id) do nothing;

    insert into public.food_items_legacy (id, restaurant_id, name, description, image_url, price, category,
                                          is_available, preparation_time, is_vegetarian, is_spicy,
                                          discount_price, discount_end_time, discount_quantity, created_at,
                                          is_happy_hour, happy_hour_price, happy_hour_start, happy_hour_end)
    values (it.id, it.vendor_id, it.name, it.description, it.image_url, it.price, it.category,
            it.is_available, it.preparation_time, it.is_vegetarian, it.is_spicy, it.discount_price,
            it.discount_end_time, it.discount_quantity, it.created_at, it.is_happy_hour,
            it.happy_hour_price, it.happy_hour_start, it.happy_hour_end)
    on conflict (id) do nothing;

  elsif v.category = 'grocery' then
    insert into public.supermarkets_legacy (id, name, description, image_url, rating, review_count,
                                            delivery_time_min, delivery_fee, min_order, is_open, latitude,
                                            longitude, created_at, is_ghost_restaurant, auto_close_enabled,
                                            opening_time, closing_time)
    values (v.id, v.name, v.description, v.image_url, v.rating, v.review_count, v.delivery_time_min,
            v.delivery_fee, v.min_order, v.is_open, v.latitude, v.longitude, v.created_at,
            v.is_ghost_restaurant, v.auto_close_enabled, v.opening_time, v.closing_time)
    on conflict (id) do nothing;

    insert into public.grocery_items_legacy (id, supermarket_id, name, description, image_url, price, category,
                                             unit, is_organic, is_available, discount_price, discount_end_time,
                                             discount_quantity, created_at, is_happy_hour, happy_hour_price,
                                             happy_hour_start, happy_hour_end)
    values (it.id, it.vendor_id, it.name, it.description, it.image_url, it.price, it.category,
            it.unit, it.is_organic, it.is_available, it.discount_price, it.discount_end_time,
            it.discount_quantity, it.created_at, it.is_happy_hour, it.happy_hour_price,
            it.happy_hour_start, it.happy_hour_end)
    on conflict (id) do nothing;
  end if;
end;
$$;

create or replace function public.mirror_vendor_item_to_legacy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.mirror_vendor_item_to_legacy_by_id(new.id);
  return null; -- AFTER trigger
end;
$$;

revoke all on function public.mirror_vendor_item_to_legacy_by_id(uuid) from public, anon, authenticated;
revoke all on function public.mirror_vendor_item_to_legacy() from public, anon, authenticated;

drop trigger if exists mirror_vendor_item_to_legacy on public.vendor_items;
create trigger mirror_vendor_item_to_legacy
after insert on public.vendor_items
for each row
execute function public.mirror_vendor_item_to_legacy();


-- ── 3. Rattrapage de ce qui manque déjà ─────────────────────────────────────
do $backfill$
declare
  r record;
begin
  for r in
    select vi.id from public.vendor_items vi
      join public.vendors v on v.id = vi.vendor_id
     where (v.category = 'food'
            and not exists (select 1 from public.food_items_legacy f where f.id = vi.id))
        or (v.category = 'grocery'
            and not exists (select 1 from public.grocery_items_legacy g where g.id = vi.id))
  loop
    perform public.mirror_vendor_item_to_legacy_by_id(r.id);
  end loop;
end
$backfill$;


-- ── Contrôle : si quelque chose manque, tout le fichier est annulé ─────────
do $check$
declare n integer;
begin
  select count(*) into n from public.vendor_items vi join public.vendors v on v.id = vi.vendor_id
   where (v.category = 'food' and not exists (select 1 from public.food_items_legacy f where f.id = vi.id))
      or (v.category = 'grocery' and not exists (select 1 from public.grocery_items_legacy g where g.id = vi.id));
  if n > 0 then
    raise exception 'order_items_legacy_mirror incomplet : % article(s) toujours absents de la copie', n;
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.vendor_items'::regclass
                    and tgname = 'mirror_vendor_item_to_legacy' and tgenabled = 'O') then
    raise exception 'order_items_legacy_mirror incomplet : trigger absent';
  end if;
  if exists (select 1 from pg_trigger where tgrelid = 'public.food_items_legacy'::regclass
                and tgname = 'auto_apply_customization_template' and tgenabled <> 'D') then
    raise exception 'order_items_legacy_mirror incomplet : le modèle de personnalisation est encore actif';
  end if;
end
$check$;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : articles_hors_copie = 0, charlot_dans_copie = true,
-- miroir_actif = true, modele_auto_coupe = true, cles_intactes = true.
select (select count(*) from public.vendor_items vi join public.vendors v on v.id = vi.vendor_id
         where (v.category = 'food' and not exists (select 1 from public.food_items_legacy f where f.id = vi.id))
            or (v.category = 'grocery' and not exists (select 1 from public.grocery_items_legacy g where g.id = vi.id)))
         as articles_hors_copie,
       exists (select 1 from public.restaurants_legacy where id = '134dd418-d329-49d9-88ad-45d33741f44d')
         as charlot_dans_copie,
       exists (select 1 from pg_trigger where tgrelid = 'public.vendor_items'::regclass
                  and tgname = 'mirror_vendor_item_to_legacy' and tgenabled = 'O') as miroir_actif,
       not exists (select 1 from pg_trigger where tgrelid = 'public.food_items_legacy'::regclass
                      and tgname = 'auto_apply_customization_template' and tgenabled <> 'D') as modele_auto_coupe,
       (select count(*) = 2 from pg_constraint
         where conrelid = 'public.order_items'::regclass
           and conname in ('order_items_food_item_id_fkey', 'order_items_grocery_item_id_fkey')
           and confrelid in ('public.food_items_legacy'::regclass, 'public.grocery_items_legacy'::regclass))
         as cles_intactes;
