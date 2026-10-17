-- ============================================================================
-- CMANDILI / Amana — Suppression de compte depuis les apps
--
-- Google Play et Apple exigent qu'un utilisateur puisse supprimer son compte
-- depuis l'app. Cette migration porte la partie serveur, commune aux trois
-- apps (client, livreur, partenaire) :
--
--   1. des colonnes pour marquer ce qui est supprimé (profil, boutique) et pour
--      clore un litige colis ;
--   2. un journal des suppressions et des refus, lisible par l'admin, SANS
--      donnée personnelle ;
--   3. le filet de sécurité sur les clés étrangères : rien de ce qui sert de
--      preuve ou d'historique financier ne doit partir en cascade ;
--   4. trois fonctions : la liste des blocages, la vérification appelée par
--      l'app, et l'exécution réservée au service_role (Edge Function
--      delete-account).
--
-- PRINCIPE. La ligne auth.users n'est JAMAIS supprimée. L'Edge Function
-- appelle ensuite la suppression « soft » de GoTrue, qui rend l'email
-- illisible et supprime identités et sessions, mais garde la ligne. Aucune
-- clé étrangère ne se déclenche, et les commandes, règlements et bons colis
-- restent intacts. Cette fonction pose en plus un bannissement : même si
-- l'appel GoTrue échoue, la personne ne peut plus se connecter.
--
-- Idempotente : peut être relancée sans effet de bord.
-- ============================================================================


-- ── 1. Colonnes ────────────────────────────────────────────────────────────

-- Le profil anonymisé garde sa ligne (les commandes s'y joignent) ; cette date
-- dit qu'il n'y a plus personne derrière. Pas de grant : profiles est en liste
-- blanche de colonnes (20260824120000), une nouvelle colonne n'est donc PAS
-- modifiable par les clients.
alter table public.profiles add column if not exists deleted_at timestamptz;

-- Boutique d'un partenaire supprimé : fermée et marquée. La ligne reste,
-- l'historique des commandes en a besoin. Le filtrage des listes côté client
-- viendra avec la phase « app client » : un filtre sur une colonne absente
-- casserait l'app tant que cette migration n'est pas appliquée.
alter table public.vendors add column if not exists deleted_at timestamptz;

-- Un litige colis n'avait pas d'état : impossible de dire s'il est encore
-- ouvert. Ouvert = resolved_at nul. La clôture se fait par l'admin.
alter table public.colis_disputes add column if not exists resolved_at timestamptz;
alter table public.colis_disputes add column if not exists resolved_by uuid;
alter table public.colis_disputes add column if not exists resolution  text;


-- ── 2. Journal ─────────────────────────────────────────────────────────────
-- user_id est un identifiant pseudonyme, sans clé étrangère, qui sert à
-- retrouver l'historique gardé. Aucun nom, email ou téléphone ici : les
-- blocages ne contiennent que des codes, des nombres et un solde.

create table if not exists public.account_deletions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null,
  app          text not null,
  roles        text[] not null default '{}',
  status       text not null,
  blockers     jsonb not null default '[]'::jsonb,
  error        text,
  created_at   timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.account_deletions drop constraint if exists account_deletions_app_check;
alter table public.account_deletions
  add constraint account_deletions_app_check
  check (app in ('client', 'driver', 'partner'));

alter table public.account_deletions drop constraint if exists account_deletions_status_check;
alter table public.account_deletions
  add constraint account_deletions_status_check
  check (status in ('blocked', 'auth_pending', 'completed', 'failed'));

create index if not exists idx_account_deletions_user    on public.account_deletions(user_id);
create index if not exists idx_account_deletions_created on public.account_deletions(created_at desc);

-- Admin seulement, et l'admin passe par le service_role. RLS active sans
-- politique : ni anon ni authenticated ne lisent ni n'écrivent.
alter table public.account_deletions enable row level security;
revoke all on table public.account_deletions from public, anon, authenticated;
grant all on table public.account_deletions to service_role;


-- ── 3. Filet de sécurité sur les clés étrangères ───────────────────────────
-- Constat du 16/10 : un DELETE sur auth.users partait en CASCADE dans
-- settlements, wallets, drivers (puis driver_identity, deliveries), partners
-- et les avis. Une suppression faite à la main depuis le dashboard effaçait
-- l'historique financier et le dossier d'identité du livreur.
-- On passe ces liens en RESTRICT : une telle suppression échoue désormais au
-- lieu d'effacer. Les tables purement personnelles (adresses, jetons push,
-- chat IA, notifications...) restent en CASCADE.
-- orders, payments et loyalty_driver_payouts.customer_id sont déjà en
-- SET NULL sur le live (changement fait hors dépôt entre le 16 et le 17/10) :
-- on n'y touche pas ici.

alter table public.settlements drop constraint if exists settlements_user_id_fkey;
alter table public.settlements
  add constraint settlements_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.wallets drop constraint if exists wallets_user_id_fkey;
alter table public.wallets
  add constraint wallets_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.drivers drop constraint if exists drivers_user_id_fkey;
alter table public.drivers
  add constraint drivers_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.partners drop constraint if exists partners_user_id_fkey;
alter table public.partners
  add constraint partners_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.order_ratings drop constraint if exists order_ratings_user_id_fkey;
alter table public.order_ratings
  add constraint order_ratings_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.driver_ratings drop constraint if exists driver_ratings_user_id_fkey;
alter table public.driver_ratings
  add constraint driver_ratings_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.reviews drop constraint if exists reviews_user_id_fkey;
alter table public.reviews
  add constraint reviews_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete restrict;

alter table public.driver_identity drop constraint if exists driver_identity_driver_id_fkey;
alter table public.driver_identity
  add constraint driver_identity_driver_id_fkey
  foreign key (driver_id) references public.drivers(id) on delete restrict;

alter table public.deliveries drop constraint if exists deliveries_driver_id_fkey;
alter table public.deliveries
  add constraint deliveries_driver_id_fkey
  foreign key (driver_id) references public.drivers(id) on delete restrict;

alter table public.driver_ratings drop constraint if exists driver_ratings_driver_id_fkey;
alter table public.driver_ratings
  add constraint driver_ratings_driver_id_fkey
  foreign key (driver_id) references public.drivers(id) on delete restrict;


-- ── 4. Blocages ────────────────────────────────────────────────────────────
-- Renvoie un tableau jsonb, vide si rien ne bloque. Chaque élément porte un
-- code que l'app traduit, plus un nombre ou un montant :
--   admin_account          compte admin : jamais supprimé depuis une app
--   active_orders          commande en cours passée par la personne
--   open_disputes          litige colis ouvert par la personne, non clos
--   driver_active_orders   livraison en cours (livreur)
--   driver_open_disputes   litige colis non clos contre ce livreur
--   driver_payouts_pending prime fidélité qu'Amana doit encore au livreur
--   shop_active_orders     commande en cours dans la boutique (partenaire)
--   wallet_balance         solde non nul : crédit à rembourser ou dû à Amana
--   settlements_pending    règlement en attente
--
-- Union de tous les rôles : un compte à la fois client et livreur doit être
-- en règle sur les deux, puisque c'est le même compte qui disparaît.
--
-- Interne : prend un uid quelconque, donc fermée à anon ET authenticated
-- (sinon n'importe qui saurait si quelqu'un a une commande en cours).

create or replace function public.account_deletion_blockers(p_uid uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
declare
  v_active constant text[] := array['pending', 'confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay'];
  v_out    jsonb := '[]'::jsonb;
  v_n      integer;
  v_amount numeric;
begin
  if exists (select 1 from public.profiles where id = p_uid and is_admin is true) then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'admin_account'));
  end if;

  -- Client
  select count(*) into v_n
    from public.orders
   where user_id = p_uid and status = any (v_active);
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'active_orders', 'count', v_n));
  end if;

  select count(*) into v_n
    from public.colis_disputes
   where user_id = p_uid and resolved_at is null;
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'open_disputes', 'count', v_n));
  end if;

  -- Livreur (orders.driver_id et colis_disputes.driver_id portent drivers.id)
  select count(*) into v_n
    from public.orders o
    join public.drivers d on d.id = o.driver_id
   where d.user_id = p_uid and o.status = any (v_active);
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'driver_active_orders', 'count', v_n));
  end if;

  select count(*) into v_n
    from public.colis_disputes cd
    join public.drivers d on d.id = cd.driver_id
   where d.user_id = p_uid and cd.resolved_at is null;
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'driver_open_disputes', 'count', v_n));
  end if;

  select count(*) into v_n
    from public.loyalty_driver_payouts lp
    join public.drivers d on d.id = lp.driver_id
   where d.user_id = p_uid and lp.status = 'pending';
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'driver_payouts_pending', 'count', v_n));
  end if;

  -- Partenaire. entity_id comparé en texte : son type a déjà divergé entre le
  -- live et le fichier de schéma (voir 20260703140000).
  select count(*) into v_n
    from public.orders o
    join public.partners p
      on p.entity_id::text = o.restaurant_id::text
      or p.entity_id::text = o.supermarket_id::text
   where p.user_id = p_uid and o.status = any (v_active);
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'shop_active_orders', 'count', v_n));
  end if;

  -- Argent. Modèle prépayé : un solde positif est un crédit qu'Amana doit
  -- rendre, un solde négatif une dette. Dans les deux cas, l'équipe Amana
  -- solde le compte avant.
  select balance into v_amount from public.wallets where user_id = p_uid;
  if v_amount is not null and abs(v_amount) >= 0.001 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'wallet_balance', 'amount', round(v_amount, 3)));
  end if;

  select count(*) into v_n
    from public.settlements
   where user_id = p_uid and status = 'pending';
  if v_n > 0 then
    v_out := v_out || jsonb_build_array(jsonb_build_object('code', 'settlements_pending', 'count', v_n));
  end if;

  return v_out;
end;
$fn$;

-- Supabase accorde EXECUTE à anon/authenticated sur toute nouvelle fonction
-- du schéma public : un revoke from public ne suffit pas, il faut les nommer.
revoke execute on function public.account_deletion_blockers(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_blockers(uuid) to service_role;


-- ── 5. Vérification depuis l'app ───────────────────────────────────────────
-- L'écran de suppression l'appelle à l'ouverture : la personne voit tout de
-- suite ce qui bloque, avant de taper quoi que ce soit. Ne regarde que
-- auth.uid() et ne modifie rien.

create or replace function public.account_deletion_check()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Non authentifié';
  end if;
  return jsonb_build_object('blockers', public.account_deletion_blockers(auth.uid()));
end;
$fn$;

revoke execute on function public.account_deletion_check() from public, anon;
grant execute on function public.account_deletion_check() to authenticated, service_role;


-- ── 6. Exécution (service_role uniquement) ─────────────────────────────────
-- Appelée par l'Edge Function delete-account, qui a déjà vérifié le JWT, la
-- ré-authentification récente et le mot « SUPPRIMER ». Tout se passe dans une
-- seule transaction : re-vérification des blocages, puis suppression des
-- données personnelles, anonymisation et journal.
--
-- Renvoie :
--   {status: 'blocked', blockers, log_id}  rien n'a été modifié
--   {status: 'already_deleted'}             appel rejoué
--   {status: 'ok', log_id, roles, avatar_url}
--      avatar_url : la photo de profil à retirer du Stockage par l'Edge
--      Function (le Stockage n'est pas transactionnel). Nulle si la photo
--      sert aussi de logo de boutique, qui est gardé.

create or replace function public.account_deletion_execute(p_uid uuid, p_app text)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_blockers jsonb;
  v_roles    text[] := '{}';
  v_log      uuid;
  v_avatar   text;
begin
  if p_uid is null then
    raise exception 'p_uid est requis';
  end if;
  if p_app is null or p_app not in ('client', 'driver', 'partner') then
    raise exception 'App inconnue : %', p_app;
  end if;

  -- Deux appels simultanés pour le même compte : le second attend le premier,
  -- puis voit already_deleted.
  perform pg_advisory_xact_lock(hashtextextended('account_deletion:' || p_uid::text, 0));

  perform 1 from auth.users where id = p_uid for update;
  if not found then
    raise exception 'Utilisateur introuvable';
  end if;

  if exists (select 1 from public.profiles where id = p_uid and deleted_at is not null) then
    return jsonb_build_object('status', 'already_deleted');
  end if;

  -- array_append / array_prepend et non || : avec un littéral, || tente de
  -- le lire comme un tableau (« malformed array literal »).
  if exists (select 1 from public.drivers  where user_id = p_uid) then v_roles := array_append(v_roles, 'driver'); end if;
  if exists (select 1 from public.partners where user_id = p_uid) then v_roles := array_append(v_roles, 'partner'); end if;
  if cardinality(v_roles) = 0 or exists (select 1 from public.orders where user_id = p_uid) then
    v_roles := array_prepend('client', v_roles);
  end if;

  -- Le solde ne doit pas bouger entre la vérification et la fin.
  perform 1 from public.wallets where user_id = p_uid for update;

  v_blockers := public.account_deletion_blockers(p_uid);
  if jsonb_array_length(v_blockers) > 0 then
    insert into public.account_deletions (user_id, app, roles, status, blockers)
    values (p_uid, p_app, v_roles, 'blocked', v_blockers)
    returning id into v_log;
    return jsonb_build_object('status', 'blocked', 'blockers', v_blockers, 'log_id', v_log);
  end if;

  -- Photo de profil, relevée avant d'être effacée. Gardée si elle sert de logo.
  select nullif(btrim(avatar_url), '') into v_avatar from public.profiles where id = p_uid;
  if v_avatar is not null and exists (
       select 1 from public.partners p
        where p.user_id = p_uid and p.avatar_url = v_avatar
       union all
       select 1 from public.vendors v
        where v.image_url = v_avatar
     ) then
    v_avatar := null;
  end if;

  -- Données purement personnelles : supprimées.
  delete from public.device_tokens       where user_id = p_uid;
  delete from public.chat_messages       where user_id = p_uid;
  delete from public.addresses           where user_id = p_uid;
  delete from public.user_addresses      where user_id = p_uid;
  delete from public.saved_recipients    where user_id = p_uid;
  delete from public.user_favorites      where user_id = p_uid;
  delete from public.payment_methods     where user_id = p_uid;
  delete from public.notifications       where user_id = p_uid;
  delete from public.loyalty_customer_progress where customer_id = p_uid;
  -- Les IBAN : le solde est à zéro (blocage ci-dessus), plus rien à verser.
  delete from public.driver_payout_info  where user_id = p_uid;
  delete from public.partner_payout_info where user_id = p_uid;

  -- Profil : la ligne reste (jointures des commandes), la personne non.
  update public.profiles
     set full_name  = 'Compte supprimé',
         phone      = null,
         email      = null,
         avatar_url = null,
         is_blocked = true,
         deleted_at = now(),
         updated_at = now()
   where id = p_uid;

  -- Livreur : hors ligne, écarté du dispatch, position effacée. Véhicule et
  -- plaque restent : ils figurent sur les bons colis.
  update public.drivers
     set is_online            = false,
         is_blocked           = true,
         current_lat          = null,
         current_lng          = null,
         last_location_update = null
   where user_id = p_uid;

  -- Partenaire : coordonnées effacées. Le nom commercial reste, c'est celui de
  -- la boutique sur les commandes passées. sync_partner_shop_fields ne
  -- recopie pas une valeur vide : la fiche boutique garde logo et description.
  update public.partners
     set phone      = null,
         address    = null,
         bio        = null,
         avatar_url = null,
         is_blocked = true
   where user_id = p_uid;

  -- Boutique : fermée et marquée. Produits et commandes passées restent. Le
  -- cron auto-close ne fait que fermer : personne ne la rouvrira.
  update public.vendors v
     set is_open    = false,
         deleted_at = now()
    from public.partners p
   where p.user_id = p_uid
     and p.entity_id::text = v.id::text;

  -- Portefeuille : gardé (historique), bloqué. 'manual' et non 'balance' : un
  -- rechargement ne débloquerait pas le compte (enforce_prepaid_block).
  update public.wallets
     set status         = 'blocked',
         blocked_reason = 'manual',
         updated_at     = now()
   where user_id = p_uid;

  -- Connexion impossible tout de suite, sans attendre GoTrue : bannissement
  -- et fin des sessions (les refresh tokens partent avec elles). Les
  -- métadonnées d'inscription contiennent nom, téléphone et photo.
  update auth.users
     set banned_until       = now() + interval '100 years',
         raw_user_meta_data = '{}'::jsonb,
         updated_at         = now()
   where id = p_uid;
  delete from auth.sessions where user_id = p_uid;

  insert into public.account_deletions (user_id, app, roles, status)
  values (p_uid, p_app, v_roles, 'auth_pending')
  returning id into v_log;

  return jsonb_build_object(
    'status',     'ok',
    'log_id',     v_log,
    'roles',      to_jsonb(v_roles),
    'avatar_url', v_avatar
  );
end;
$fn$;

revoke execute on function public.account_deletion_execute(uuid, text) from public, anon, authenticated;
grant execute on function public.account_deletion_execute(uuid, text) to service_role;
