-- ============================================================================
-- CMANDILI / Amana — Harnais : 20261030120000_order_items_legacy_mirror
--
-- SÛR À LANCER EN PRODUCTION : une transaction terminée par ROLLBACK. Les
-- triggers UTILISATEUR de orders sont coupés le temps du test (pas de push) ;
-- celui de order_items (happy hour) tourne comme d'habitude.
--
-- Avec de VRAIS articles du live, une commande par type de boutique, les
-- lignes écrites par le client comme le fait l'app :
--   M1  restaurant : un plat de la boutique la plus récente (Charlot au 30/10,
--       créée après le gel des copies du 22/09) -> food_item_id
--   M2  supermarché : un produit -> grocery_item_id
--   M3  boutiques : un produit de chaque catégorie (pâtisserie, fleurs,
--       animaux, cadeaux, électronique) -> vendor_item_id
--   M4  un plat que le partenaire ajoute après la migration est recopié et
--       peut être commandé
--   M5  un article qui n'existe nulle part est toujours refusé
--   M6  ce que lisent les écrans de commandes (jointures sur les copies)
--       trouve le nom du plat et du produit
--   M7  un nouveau plat « Mlawi » ne reçoit ni suppléments ni variantes
--       d'office (le modèle de personnalisation reste coupé)
--   M8  le client peut mettre le restaurant en favori, et l'écran des
--       favoris le retrouve
-- Sans la migration, M1 échoue (order_items_food_item_id_fkey).
-- ============================================================================

begin;

do $test$
declare
  u_c uuid := gen_random_uuid();
  u_p uuid;
  food_item uuid; food_shop uuid; food_name text;
  groc_item uuid; groc_shop uuid; groc_name text;
  b record;
  bout_orders uuid[] := '{}'; bout_items uuid[] := '{}'; bout_names text := '';
  new_item uuid := gen_random_uuid();
  mlawi_item uuid := gen_random_uuid();
  o1 uuid; o2 uuid; o3 uuid; o4 uuid;
  res text := '';
begin
  alter table public.orders disable trigger user;

  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
  values (u_c, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'mirrortest-' || u_c::text || '@test.invalid', '{}'::jsonb,
          '{"provider":"email","providers":["email"]}'::jsonb, now(), now());
  update public.profiles set is_admin = false, is_blocked = false where id = u_c;

  select vi.id, vi.vendor_id, v.name || ' / ' || vi.name into food_item, food_shop, food_name
    from public.vendor_items vi join public.vendors v on v.id = vi.vendor_id
   where v.category = 'food' and v.deleted_at is null and vi.is_available
   order by v.created_at desc, vi.created_at desc limit 1;
  select vi.id, vi.vendor_id, v.name || ' / ' || vi.name into groc_item, groc_shop, groc_name
    from public.vendor_items vi join public.vendors v on v.id = vi.vendor_id
   where v.category = 'grocery' and v.deleted_at is null and vi.is_available
   order by vi.created_at desc limit 1;
  if food_item is null or groc_item is null then
    raise exception 'FAIL : il manque un type de boutique (plat %, produit %)', food_item, groc_item;
  end if;
  select p.user_id into u_p from public.partners p
   where p.entity_id = food_shop and not coalesce(p.is_blocked, false) limit 1;
  if u_p is null then
    raise exception 'FAIL : % n''a pas de partenaire actif', food_name;
  end if;

  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, food_shop, 'pending', 'food', 10, 3.5, 13.5, 'cash', false) returning id into o1;
  insert into public.orders (user_id, supermarket_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, groc_shop, 'pending', 'grocery', 10, 5, 15, 'cash', false) returning id into o2;
  for b in
    select distinct on (v.category) vi.id as item, vi.vendor_id as shop, v.category as cat,
           v.category || ' ' || v.name || ' / ' || vi.name as label
      from public.vendor_items vi join public.vendors v on v.id = vi.vendor_id
     where v.category not in ('food', 'grocery') and v.deleted_at is null and vi.is_available
     order by v.category, vi.created_at desc
  loop
    insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
    values (u_c, b.shop, 'pending', b.cat, 10, 3.5, 13.5, 'cash', false) returning id into o3;
    bout_orders := bout_orders || o3;
    bout_items := bout_items || b.item;
    bout_names := bout_names || ', ' || b.label;
  end loop;
  if cardinality(bout_items) = 0 then
    raise exception 'FAIL : aucune boutique avec un produit disponible';
  end if;
  insert into public.orders (user_id, restaurant_id, status, order_type, subtotal, delivery_fee, total, payment_method, self_delivery)
  values (u_c, food_shop, 'pending', 'food', 5, 3.5, 8.5, 'cash', false) returning id into o4;

  -- ── M1 M2 M3 : une ligne par type de boutique, écrite par le client ──────
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.order_items (order_id, food_item_id, quantity, price, options) values (o1, food_item, 1, 10, '{}');
  insert into public.order_items (order_id, grocery_item_id, quantity, price, options) values (o2, groc_item, 1, 10, '{}');
  for i in 1 .. cardinality(bout_items) loop
    insert into public.order_items (order_id, vendor_item_id, quantity, price, options)
    values (bout_orders[i], bout_items[i], 1, 10, '{}');
  end loop;
  reset role;
  res := res || 'M1 ' || food_name || '; M2 ' || groc_name || '; M3 ' || cardinality(bout_items)
         || ' catégories (' || substr(bout_names, 3) || '); ';

  -- ── M4 M7 : le partenaire ajoute deux plats ─────────────────────────────
  perform set_config('request.jwt.claims', json_build_object('sub', u_p, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.vendor_items (id, vendor_id, name, description, price, is_available)
  values (new_item, food_shop, 'Plat de test du miroir', '', 5, true);
  insert into public.vendor_items (id, vendor_id, name, description, price, is_available)
  values (mlawi_item, food_shop, 'Mlawi test du miroir', '', 6, true);
  reset role;
  if not exists (select 1 from public.food_items_legacy where id = new_item)
     or not exists (select 1 from public.food_items_legacy where id = mlawi_item) then
    raise exception 'FAIL M4 : le nouveau plat n''est pas recopié';
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', u_c, 'role', 'authenticated')::text, true);
  set local role authenticated;
  insert into public.order_items (order_id, food_item_id, quantity, price, options) values (o4, new_item, 1, 5, '{}');
  reset role;
  res := res || 'M4 ok; ';

  if exists (select 1 from public.food_item_option_group_links where food_item_id = mlawi_item)
     or exists (select 1 from public.food_item_variants where food_item_id = mlawi_item)
     or exists (select 1 from public.food_item_option_groups where restaurant_id = food_shop)
     or exists (select 1 from public.restaurant_option_template_state where restaurant_id = food_shop) then
    raise exception 'FAIL M7 : le modèle a ajouté des suppléments ou des variantes au nouveau plat';
  end if;
  res := res || 'M7 ok; ';

  -- ── M5 l'intégrité tient ─────────────────────────────────────────────────
  begin
    set local role authenticated;
    insert into public.order_items (order_id, food_item_id, quantity, price, options)
    values (o1, gen_random_uuid(), 1, 1, '{}');
    raise exception 'FAIL M5 : un plat inexistant est accepté';
  exception when foreign_key_violation then null;
  end;
  reset role;
  res := res || 'M5 ok; ';

  -- ── M6 ce que lisent les écrans de commandes ─────────────────────────────
  if (select f.name from public.order_items oi join public.food_items_legacy f on f.id = oi.food_item_id
       where oi.order_id = o1) is null
     or (select g.name from public.order_items oi join public.grocery_items_legacy g on g.id = oi.grocery_item_id
          where oi.order_id = o2) is null then
    raise exception 'FAIL M6 : un écran de commande ne trouverait pas le nom de l''article';
  end if;
  res := res || 'M6 ok; ';

  -- ── M8 favori ────────────────────────────────────────────────────────────
  set local role authenticated;
  insert into public.user_favorites (user_id, restaurant_id) values (u_c, food_shop);
  reset role;
  if (select r.name from public.user_favorites uf join public.restaurants_legacy r on r.id = uf.restaurant_id
       where uf.user_id = u_c) is null then
    raise exception 'FAIL M8 : l''écran des favoris ne trouverait pas le restaurant';
  end if;
  res := res || 'M8 ok';

  alter table public.orders enable trigger user;
  perform set_config('mirror.results', res, true);
end
$test$;

select current_setting('mirror.results', true) as resultats;

rollback;
