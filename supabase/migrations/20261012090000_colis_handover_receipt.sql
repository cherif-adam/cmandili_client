-- ============================================================================
-- CMANDILI — Bon de prise en charge électronique pour les Colis
--
-- NON EXÉCUTÉ. À relire, puis à lancer vous-même dans le SQL Editor.
-- (Rappel : cet en-tête veut dire « à lancer vous-même », pas « jamais
--  lancée » — seule la base fait foi. Voir 20260930090000.)
--
-- Protéger les deux côtés d'une livraison Colis : le client si un livreur
-- perd ou vole un colis, le livreur si un client prétend n'avoir rien reçu.
-- Preuve à la prise en charge, preuve à la remise, et personne ne peut
-- réécrire ni l'une ni l'autre après coup.
--
-- ── CE QUI NE CHANGE PAS ───────────────────────────────────────────────────
-- Le dispatch (broadcast par paliers sur restaurant_id IS NULL) et le calcul
-- des commissions (generate_settlements_on_delivery, 10 % / 23 %) ne sont pas
-- touchés. Ce fichier ne redéfinit aucune de ces fonctions.
--
-- En revanche il déplace le MOMENT où le passage à 'delivered' arrive, donc
-- le moment où le règlement part. C'est voulu : un livreur bloqué sur un code
-- n'est pas réglé tant qu'un admin n'a pas tranché. Rien ne se perd, tout est
-- décalé.
--
-- ── POURQUOI PLUSIEURS TABLES ET NON DES COLONNES SUR orders ───────────────
-- Deux raisons, toutes deux structurelles :
--
-- 1. aa_guard_orders_column_scope (20260703130000) est deny-by-default : une
--    colonne ajoutée à `orders` plus tard est automatiquement interdite à
--    tout le monde sauf aux SECURITY DEFINER. Les preuves passent donc par
--    des RPC, ce qui nous donne gratuitement l'horodatage serveur et
--    l'immuabilité exigés.
--
-- 2. PostgreSQL n'a pas de RLS par colonne, et un REVOKE par colonne ne bat
--    pas un GRANT au niveau table. « Le CIN n'est visible que des admins » et
--    « le livreur ne doit jamais lire le code » ne peuvent donc PAS être
--    tenus par des colonnes d'une table que le client ou le livreur lit.
--    D'où trois tables :
--
--      colis_receipts           le reçu, lisible par l'expéditeur, le livreur
--                               assigné et les admins. Ni CIN ni code dedans.
--      colis_receipt_identity   CIN figé à la prise en charge. ADMINS SEULS.
--      colis_delivery_codes     le code en clair. Expéditeur + admins. Le
--                               livreur n'a AUCUNE policy : la table est
--                               invisible pour lui, pas seulement illisible.
--
-- ── OÙ VIT LE CODE, ET POURQUOI PAS DE HASH DANS LE REÇU ──────────────────
-- Le clair ET son hash sha256 vivent tous deux dans colis_delivery_codes.
-- Le reçu n'en porte AUCUNE trace, seulement le compteur de tentatives.
--
-- Mettre le hash dans colis_receipts aurait été inutile et trompeur : un code
-- à 4 chiffres n'a que 10 000 valeurs, donc un hash lisible par le livreur
-- assigné se casse par force brute en une seconde. Le code n'aurait plus rien
-- protégé.
--
-- Et puisque le clair voisine le hash dans la même ligne, ce qui protège
-- réellement ici est l'ISOLATION RLS, pas le hachage : le livreur n'a aucune
-- policy sur cette table. Le hash reste parce que la vérification compare des
-- empreintes plutôt que de manipuler le code en clair dans la fonction — pas
-- parce qu'il ajouterait une barrière. Le clair est indispensable : le cahier
-- des charges veut que l'expéditeur relise et partage son code depuis le
-- suivi, ce qu'un hash seul interdirait.
--
-- sha256() est natif depuis PG11, aucune extension requise.
--
-- ── DÉPLOIEMENT SOUPLE ─────────────────────────────────────────────────────
-- Les APK livreurs déjà installés ne connaissent pas ce flux. Tant que
-- platform_settings.colis_proof_enforcement vaut 'soft', la base accepte
-- encore un passage à 'delivered' sans preuve et marque le reçu
-- proof_status = 'missing'. Le jour où les chiffres le permettent, passer la
-- valeur à 'hard' suffit — aucun redéploiement.
--
-- Idempotent — rejouable sans effet de bord.
-- ============================================================================

begin;

-- ── 1. Réglages plateforme ─────────────────────────────────────────────────
-- Une seule table pour la valeur maximale déclarée et le palier de
-- durcissement. Lisible par tout utilisateur connecté (le client a besoin du
-- plafond pour valider son formulaire), écrite par les seuls admins.

create table if not exists public.platform_settings (
  key         text primary key,
  value       text        not null,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid
);

insert into public.platform_settings (key, value, description) values
  ('colis_max_declared_value', '300',
   'Valeur déclarée maximale d''un colis, en TND. Au-delà, l''app refuse et propose de scinder l''envoi.'),
  ('colis_proof_enforcement', 'soft',
   'soft = la base accepte une livraison sans preuve et la marque missing. hard = elle la refuse.')
on conflict (key) do nothing;

alter table public.platform_settings enable row level security;

drop policy if exists platform_settings_read_all on public.platform_settings;
create policy platform_settings_read_all
  on public.platform_settings for select
  to authenticated
  using (true);

drop policy if exists platform_settings_admin_write on public.platform_settings;
create policy platform_settings_admin_write
  on public.platform_settings for all
  to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));

create or replace function public.platform_setting(p_key text)
returns text
language sql
stable
security definer
set search_path to ''
as $$ select value from public.platform_settings where key = p_key $$;


-- ── 2. CIN du livreur — admins seuls ───────────────────────────────────────
-- Table à part plutôt qu'une colonne sur `drivers` : `drivers` est lue par
-- l'app livreur et par le client (nom, plaque, note), et PostgreSQL ne sait
-- pas masquer une colonne à l'intérieur d'un SELECT autorisé. Isoler est la
-- seule façon de tenir « jamais visible du client ».

create table if not exists public.driver_identity (
  driver_id  uuid primary key references public.drivers(id) on delete cascade,
  cin        text not null,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

alter table public.driver_identity enable row level security;

-- Aucune policy pour le livreur ni pour le client : la table leur est
-- totalement invisible, y compris leur propre ligne.
drop policy if exists driver_identity_admin_only on public.driver_identity;
create policy driver_identity_admin_only
  on public.driver_identity for all
  to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));


-- Le CIN figé sur un reçu donné. Encore une table séparée, pour la même
-- raison : le reçu lui-même est lu par l'expéditeur, le CIN ne doit jamais
-- s'y trouver. Figé et non joint, pour qu'un CIN corrigé plus tard ne
-- réécrive pas une preuve passée.
create table if not exists public.colis_receipt_identity (
  order_id   uuid primary key references public.orders(id) on delete cascade,
  driver_cin text,
  frozen_at  timestamptz not null default now()
);

alter table public.colis_receipt_identity enable row level security;

drop policy if exists colis_receipt_identity_admin_only on public.colis_receipt_identity;
create policy colis_receipt_identity_admin_only
  on public.colis_receipt_identity for all
  to authenticated
  using      (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));


-- ── 3. Le reçu ─────────────────────────────────────────────────────────────

create table if not exists public.colis_receipts (
  order_id            uuid primary key references public.orders(id) on delete cascade,

  -- Identité figée à la prise en charge. Recopiée et non jointe : une plaque
  -- ou un nom modifié après coup ne doit pas réécrire une preuve passée.
  sender_name         text,
  sender_phone        text,
  driver_id           uuid references public.drivers(id),
  driver_name         text,
  driver_plate        text,

  -- Déclaré par l'expéditeur à la commande.
  description         text,
  declared_value      numeric(12,3),

  -- Mode de remise, choisi par l'expéditeur.
  --   code    : le destinataire donne un code à 4 chiffres.
  --   no_code : remise à un tiers identifié (gardien d'école...), la preuve
  --             est la photo + le GPS, et l'expéditeur l'a accepté.
  delivery_mode       text not null default 'code',
  receiver_label      text,
  no_code_accepted_at timestamptz,

  -- PAS de hash du code ici. Un code à 4 chiffres n'a que 10 000 valeurs :
  -- un hash sha256 lisible par le livreur assigné se casse instantanément
  -- par force brute, ce qui annulerait tout l'intérêt du code. Le hash vit
  -- dans colis_delivery_codes, sur laquelle le livreur n'a aucune policy.
  -- Seul le compteur de tentatives reste ici, il n'apprend rien.
  code_attempts       integer not null default 0,
  code_locked_at      timestamptz,

  -- Prise en charge.
  pickup_photo_path   text,
  pickup_at           timestamptz,
  pickup_lat          double precision,
  pickup_lng          double precision,
  pickup_app_version  text,

  -- Remise.
  delivery_photo_path text,
  delivery_at         timestamptz,
  delivery_lat        double precision,
  delivery_lng        double precision,
  delivery_distance_m integer,
  code_verified       boolean,
  delivery_app_version text,

  -- Clôture forcée par un admin quand le code est perdu.
  admin_override_by     uuid,
  admin_override_reason text,
  admin_override_at     timestamptz,

  -- Déploiement souple.
  proof_status        text not null default 'pending',

  created_at          timestamptz not null default now()
);

alter table public.colis_receipts
  drop constraint if exists colis_receipts_delivery_mode_check;
alter table public.colis_receipts
  add constraint colis_receipts_delivery_mode_check
  check (delivery_mode in ('code', 'no_code'));

alter table public.colis_receipts
  drop constraint if exists colis_receipts_proof_status_check;
alter table public.colis_receipts
  add constraint colis_receipts_proof_status_check
  check (proof_status in ('pending', 'pickup_only', 'complete', 'missing'));

create index if not exists idx_colis_receipts_driver on public.colis_receipts(driver_id);
create index if not exists idx_colis_receipts_status on public.colis_receipts(proof_status);

alter table public.colis_receipts enable row level security;

-- Lecture : l'expéditeur sur sa commande, le livreur assigné sur la sienne,
-- les admins partout. Aucune policy d'écriture : tout passe par les RPC
-- SECURITY DEFINER plus bas, ce qui rend l'immuabilité tenable.
drop policy if exists colis_receipts_read on public.colis_receipts;
create policy colis_receipts_read
  on public.colis_receipts for select
  to authenticated
  using (
    exists (select 1 from public.orders o
             where o.id = colis_receipts.order_id
               and o.user_id = auth.uid())
    or driver_id in (select d.id from public.drivers d where d.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );


-- ── 4. Le code en clair — expéditeur et admins seulement ───────────────────

create table if not exists public.colis_delivery_codes (
  order_id  uuid primary key references public.orders(id) on delete cascade,
  code      text not null,
  -- Le hash est ici et NON dans le reçu : 4 chiffres = 10 000 valeurs, donc
  -- un hash visible du livreur se casse par force brute en une seconde.
  -- Ce que la séparation protège vraiment, c'est la RLS — pas le hash, qui
  -- voisine le clair dans cette même ligne. Il reste parce que la
  -- vérification compare des hashes et non des chaînes, ce qui évite de
  -- manipuler le code en clair dans la fonction.
  code_hash text
);

alter table public.colis_delivery_codes
  add column if not exists code_hash text;

alter table public.colis_delivery_codes enable row level security;

-- Le livreur n'a aucune policy ici. Ce n'est pas « il ne peut pas lire la
-- bonne ligne » : la table entière n'existe pas pour lui.
drop policy if exists colis_codes_sender_read on public.colis_delivery_codes;
create policy colis_codes_sender_read
  on public.colis_delivery_codes for select
  to authenticated
  using (
    exists (select 1 from public.orders o
             where o.id = colis_delivery_codes.order_id
               and o.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );


-- ── 5. Immuabilité ─────────────────────────────────────────────────────────
-- Une preuve écrite ne se réécrit plus. Le trigger compare OLD et NEW et
-- refuse toute modification d'un bloc déjà renseigné — y compris par un
-- admin, y compris par un SECURITY DEFINER. La seule marge laissée est le
-- compteur de tentatives et la clôture admin, qui sont des ajouts, pas des
-- réécritures.

create or replace function public.colis_receipt_immutable()
returns trigger
language plpgsql
as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'Un bon de prise en charge ne se supprime pas (commande %)', old.order_id;
  end if;

  -- Bloc prise en charge figé dès qu'il porte un horodatage.
  if old.pickup_at is not null and (
       new.pickup_at          is distinct from old.pickup_at
    or new.pickup_photo_path  is distinct from old.pickup_photo_path
    or new.pickup_lat         is distinct from old.pickup_lat
    or new.pickup_lng         is distinct from old.pickup_lng
    or new.driver_id          is distinct from old.driver_id
    or new.driver_name        is distinct from old.driver_name
    or new.driver_plate       is distinct from old.driver_plate
  ) then
    raise exception 'La prise en charge de la commande % est déjà enregistrée', old.order_id;
  end if;

  -- Bloc remise, idem.
  if old.delivery_at is not null and (
       new.delivery_at         is distinct from old.delivery_at
    or new.delivery_photo_path is distinct from old.delivery_photo_path
    or new.delivery_lat        is distinct from old.delivery_lat
    or new.delivery_lng        is distinct from old.delivery_lng
    or new.code_verified       is distinct from old.code_verified
  ) then
    raise exception 'La remise de la commande % est déjà enregistrée', old.order_id;
  end if;

  -- Ce que l'expéditeur a déclaré reste modifiable TANT QUE le colis n'a pas
  -- été pris en charge — il peut corriger une valeur ou passer en remise sans
  -- code juste après avoir commandé. Dès que le livreur l'a en main, c'est
  -- figé : sinon on pourrait relever la valeur déclarée après coup, une fois
  -- le colis perdu.
  if old.pickup_at is not null and (
       new.declared_value is distinct from old.declared_value
    or new.delivery_mode  is distinct from old.delivery_mode
    or new.receiver_label is distinct from old.receiver_label
    or new.description    is distinct from old.description
  ) then
    raise exception 'Le colis de la commande % est déjà pris en charge, la déclaration est figée', old.order_id;
  end if;

  if new.created_at is distinct from old.created_at then
    raise exception 'created_at n''est pas modifiable (commande %)', old.order_id;
  end if;

  -- Une clôture admin ne se rejoue pas.
  if old.admin_override_at is not null
     and new.admin_override_at is distinct from old.admin_override_at then
    raise exception 'La commande % a déjà été clôturée par un admin', old.order_id;
  end if;

  return new;
end;
$fn$;

-- Supabase accorde EXECUTE a anon/authenticated sur toute nouvelle fonction
-- du schema public (ALTER DEFAULT PRIVILEGES). Un `revoke from public` ne
-- retire PAS cet octroi nominatif : il faut nommer anon. Le revoke suit
-- immediatement la creation, car re-creer la fonction re-applique les
-- privileges par defaut.
revoke execute on function public.colis_receipt_immutable() from public, anon, authenticated;

drop trigger if exists trg_colis_receipt_immutable on public.colis_receipts;
create trigger trg_colis_receipt_immutable
  before update or delete on public.colis_receipts
  for each row execute function public.colis_receipt_immutable();

-- Le code ne se réécrit pas davantage.
create or replace function public.colis_code_immutable()
returns trigger
language plpgsql
as $fn$
begin
  raise exception 'Le code de livraison de la commande % n''est ni modifiable ni supprimable',
    coalesce(old.order_id, new.order_id);
end;
$fn$;

-- Supabase accorde EXECUTE a anon/authenticated sur toute nouvelle fonction
-- du schema public (ALTER DEFAULT PRIVILEGES). Un `revoke from public` ne
-- retire PAS cet octroi nominatif : il faut nommer anon. Le revoke suit
-- immediatement la creation, car re-creer la fonction re-applique les
-- privileges par defaut.
revoke execute on function public.colis_code_immutable() from public, anon, authenticated;

drop trigger if exists trg_colis_code_immutable on public.colis_delivery_codes;
create trigger trg_colis_code_immutable
  before update or delete on public.colis_delivery_codes
  for each row execute function public.colis_code_immutable();


-- ── 6. Création automatique du reçu et du code ─────────────────────────────
-- À l'insertion d'une commande courier. L'app cliente continue d'insérer sa
-- commande comme avant : elle n'a pas à connaître ces tables.

create or replace function public.colis_bootstrap_receipt()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_code text;
begin
  if new.order_type <> 'courier' then
    return new;
  end if;

  -- 4 chiffres, 0000 compris : c'est un code de remise en main propre, pas un
  -- secret cryptographique, et le nombre de tentatives est plafonné à 5.
  v_code := lpad((floor(random() * 10000))::int::text, 4, '0');

  insert into public.colis_receipts (
    order_id, sender_phone, description, declared_value, delivery_mode,
    proof_status
  ) values (
    new.id,
    new.sender_phone,
    new.package_description,
    null,
    'code',
    'pending'
  )
  on conflict (order_id) do nothing;

  -- Le clair ET le hash vont dans la table que le livreur ne voit pas.
  insert into public.colis_delivery_codes (order_id, code, code_hash)
  values (
    new.id,
    v_code,
    encode(sha256(convert_to(v_code || new.id::text, 'UTF8')), 'hex')
  )
  on conflict (order_id) do nothing;

  return new;
end;
$fn$;

-- Supabase accorde EXECUTE a anon/authenticated sur toute nouvelle fonction
-- du schema public (ALTER DEFAULT PRIVILEGES). Un `revoke from public` ne
-- retire PAS cet octroi nominatif : il faut nommer anon. Le revoke suit
-- immediatement la creation, car re-creer la fonction re-applique les
-- privileges par defaut.
revoke execute on function public.colis_bootstrap_receipt() from public, anon, authenticated;

drop trigger if exists trg_colis_bootstrap_receipt on public.orders;
create trigger trg_colis_bootstrap_receipt
  after insert on public.orders
  for each row execute function public.colis_bootstrap_receipt();


-- ── 7. Distance entre deux points ──────────────────────────────────────────
-- Haversine en plpgsql plutôt que earthdistance : une dépendance d'extension
-- de moins pour un calcul de cette taille.

create or replace function public.colis_distance_m(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
) returns integer
language sql
immutable
as $$
  select case
    when lat1 is null or lng1 is null or lat2 is null or lng2 is null then null
    else (6371000 * 2 * asin(sqrt(
           power(sin(radians(lat2 - lat1) / 2), 2)
         + cos(radians(lat1)) * cos(radians(lat2))
         * power(sin(radians(lng2 - lng1) / 2), 2)
         )))::integer
  end
$$;

-- Supabase accorde EXECUTE a anon/authenticated sur toute nouvelle fonction
-- du schema public (ALTER DEFAULT PRIVILEGES). Un `revoke from public` ne
-- retire PAS cet octroi nominatif : il faut nommer anon. Le revoke suit
-- immediatement la creation, car re-creer la fonction re-applique les
-- privileges par defaut.
revoke execute on function public.colis_distance_m(
  double precision, double precision, double precision, double precision
) from public, anon, authenticated;

-- ── 8. Litiges ─────────────────────────────────────────────────────────────
-- Une table dédiée en plus du ticket de support : elle sert au comptage par
-- client et par livreur que les admins doivent voir, ce qu'une liste de
-- tickets en texte libre ne donne pas.

create table if not exists public.colis_disputes (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null references public.orders(id) on delete cascade,
  user_id    uuid not null,
  driver_id  uuid,
  kind       text not null,
  message    text,
  created_at timestamptz not null default now()
);

alter table public.colis_disputes
  drop constraint if exists colis_disputes_kind_check;
alter table public.colis_disputes
  add constraint colis_disputes_kind_check
  check (kind in ('not_received', 'parcel_problem'));

create index if not exists idx_colis_disputes_user   on public.colis_disputes(user_id);
create index if not exists idx_colis_disputes_driver on public.colis_disputes(driver_id);

alter table public.colis_disputes enable row level security;

drop policy if exists colis_disputes_read on public.colis_disputes;
create policy colis_disputes_read
  on public.colis_disputes for select
  to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
  );


-- ── 8bis. Création atomique d'une commande Colis ───────────────────────────
-- Une commande Colis naît en 'ready' et part immédiatement en broadcast aux
-- livreurs. Elle ne doit donc JAMAIS exister sans sa déclaration : un livreur
-- pourrait l'accepter et se retrouver devant un colis sans valeur déclarée ni
-- mode de remise.
--
-- Tout est fait ici dans une seule transaction : validation, insertion de la
-- commande, création du reçu et du code par le trigger AFTER INSERT, puis
-- écriture de la déclaration. Une erreur à n'importe quelle étape annule
-- l'ensemble — aucune commande orpheline possible.
--
-- Les frais de livraison restent calculés par l'app, comme aujourd'hui : le
-- barème vit dans delivery_fee.dart et le recopier ici créerait deux sources
-- de vérité pour un montant. Ce point ne change donc pas de niveau de
-- confiance par rapport à l'insertion directe qu'il remplace.

create or replace function public.create_colis_order(
  p_pickup_address    jsonb,
  p_delivery_address  jsonb,
  p_sender_phone      text,
  p_recipient_phone   text,
  p_package_size      text,
  p_description       text,
  p_declared_value    numeric,
  p_delivery_fee      numeric,
  p_recipient_name    text default null,
  p_mode              text default 'code',
  p_receiver_label    text default null,
  p_package_photo_url text default null,
  p_eta               timestamptz default null
) returns uuid
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_uid      uuid := auth.uid();
  v_max      numeric;
  v_order_id uuid;
begin
  if v_uid is null then
    raise exception 'Connexion requise';
  end if;

  -- Tout est validé AVANT d'écrire quoi que ce soit : échouer tôt évite de
  -- consommer un identifiant de commande pour rien.
  if p_mode not in ('code', 'no_code') then
    raise exception 'Mode de remise inconnu : %', p_mode;
  end if;
  if coalesce(btrim(coalesce(p_description, '')), '') = '' then
    raise exception 'La description du colis est obligatoire';
  end if;
  if p_declared_value is null or p_declared_value <= 0 then
    raise exception 'La valeur déclarée est obligatoire';
  end if;

  v_max := coalesce(public.platform_setting('colis_max_declared_value')::numeric, 300);
  if p_declared_value > v_max then
    raise exception 'La valeur déclarée dépasse le plafond de % TND. Scindez l''envoi en plusieurs colis.', v_max;
  end if;

  if p_mode = 'no_code' and coalesce(btrim(coalesce(p_receiver_label, '')), '') = '' then
    raise exception 'En remise sans code, il faut indiquer à qui le colis sera remis';
  end if;
  if p_pickup_address is null or p_delivery_address is null then
    raise exception 'Les adresses de retrait et de livraison sont obligatoires';
  end if;
  if coalesce(btrim(coalesce(p_sender_phone, '')), '') = ''
     or coalesce(btrim(coalesce(p_recipient_phone, '')), '') = '' then
    raise exception 'Les numéros de l''expéditeur et du destinataire sont obligatoires';
  end if;

  insert into public.orders (
    user_id, status, subtotal, delivery_fee, total, payment_method,
    notes, delivery_address, pickup_address, order_type,
    package_description, package_size, sender_phone,
    recipient_name, recipient_phone, package_photo_url,
    estimated_delivery_time
  ) values (
    v_uid, 'ready', 0, p_delivery_fee, p_delivery_fee, 'cash',
    btrim(p_description), p_delivery_address, p_pickup_address, 'courier',
    btrim(p_description), p_package_size, btrim(p_sender_phone),
    nullif(btrim(coalesce(p_recipient_name, '')), ''), btrim(p_recipient_phone),
    p_package_photo_url,
    coalesce(p_eta, now() + interval '45 minutes')
  )
  returning id into v_order_id;

  -- Le trigger AFTER INSERT a créé le reçu et le code dans cette même
  -- transaction ; il ne reste qu'à y poser la déclaration.
  update public.colis_receipts set
    description         = btrim(p_description),
    declared_value      = p_declared_value,
    delivery_mode       = p_mode,
    receiver_label      = case when p_mode = 'no_code' then btrim(p_receiver_label) else null end,
    no_code_accepted_at = case when p_mode = 'no_code' then now() else null end
  where order_id = v_order_id;

  if not found then
    raise exception 'Le bon de prise en charge n''a pas été créé pour la commande %', v_order_id;
  end if;

  return v_order_id;
end;
$fn$;


-- ── 8ter. Déclaration de l'expéditeur ──────────────────────────────────────
-- Appelée juste après la création de la commande. C'est ici que le plafond
-- est vérifié côté SERVEUR : le contrôle dans l'app est du confort, celui-ci
-- est la règle. Possible tant que le colis n'est pas pris en charge.

create or replace function public.colis_set_declaration(
  p_order_id       uuid,
  p_description    text,
  p_declared_value numeric,
  p_mode           text default 'code',
  p_receiver_label text default null
) returns public.colis_receipts
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_order   public.orders%rowtype;
  v_receipt public.colis_receipts%rowtype;
  v_max     numeric;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null or v_order.user_id is distinct from auth.uid() then
    raise exception 'Commande introuvable';
  end if;
  if v_order.order_type <> 'courier' then
    raise exception 'Cette commande n''est pas un colis';
  end if;
  if p_mode not in ('code', 'no_code') then
    raise exception 'Mode de remise inconnu : %', p_mode;
  end if;
  if coalesce(btrim(p_description), '') = '' then
    raise exception 'La description du colis est obligatoire';
  end if;

  v_max := coalesce(public.platform_setting('colis_max_declared_value')::numeric, 300);
  if p_declared_value is null or p_declared_value <= 0 then
    raise exception 'La valeur déclarée est obligatoire';
  end if;
  if p_declared_value > v_max then
    raise exception 'La valeur déclarée dépasse le plafond de % TND. Scindez l''envoi en plusieurs colis.', v_max;
  end if;

  if p_mode = 'no_code' and coalesce(btrim(coalesce(p_receiver_label, '')), '') = '' then
    raise exception 'En remise sans code, il faut indiquer à qui le colis sera remis';
  end if;

  select * into v_receipt from public.colis_receipts where order_id = p_order_id;
  if v_receipt.order_id is null then
    raise exception 'Aucun bon de prise en charge pour la commande %', p_order_id;
  end if;
  if v_receipt.pickup_at is not null then
    raise exception 'Le colis est déjà pris en charge, la déclaration ne peut plus changer';
  end if;

  update public.colis_receipts set
    description         = btrim(p_description),
    declared_value      = p_declared_value,
    delivery_mode       = p_mode,
    receiver_label      = case when p_mode = 'no_code' then btrim(p_receiver_label) else null end,
    -- Horodatage serveur de l'acceptation : en mode sans code, c'est la
    -- preuve que l'expéditeur a accepté que la photo et le GPS tiennent lieu
    -- de reçu.
    no_code_accepted_at = case when p_mode = 'no_code' then now() else null end
  where order_id = p_order_id
  returning * into v_receipt;

  return v_receipt;
end;
$fn$;


-- ── 9. Prise en charge ─────────────────────────────────────────────────────

create or replace function public.colis_record_pickup(
  p_order_id    uuid,
  p_photo_path  text,
  p_lat         double precision,
  p_lng         double precision,
  p_app_version text default null
) returns public.colis_receipts
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_driver  public.drivers%rowtype;
  v_order   public.orders%rowtype;
  v_cin     text;
  v_name    text;
  v_receipt public.colis_receipts%rowtype;
begin
  select * into v_driver from public.drivers where user_id = auth.uid();
  if v_driver.id is null then
    raise exception 'Seul un livreur peut enregistrer une prise en charge';
  end if;

  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Commande introuvable';
  end if;
  if v_order.order_type <> 'courier' then
    raise exception 'Cette commande n''est pas un colis';
  end if;
  if v_order.driver_id is distinct from v_driver.id then
    raise exception 'Cette commande n''est pas assignée à ce livreur';
  end if;
  if coalesce(p_photo_path, '') = '' then
    raise exception 'La photo du colis est obligatoire';
  end if;

  select cin into v_cin from public.driver_identity where driver_id = v_driver.id;
  select full_name into v_name from public.profiles where id = auth.uid();

  -- Le CIN est figé sur le reçu, mais dans sa propre table : il ne doit
  -- jamais se retrouver dans une ligne que l'expéditeur peut lire. La ligne
  -- est écrite même quand le CIN est inconnu, pour que l'admin voie la
  -- différence entre « pas renseigné » et « pas de prise en charge ».
  insert into public.colis_receipt_identity (order_id, driver_cin)
  values (p_order_id, v_cin)
  on conflict (order_id) do nothing;

  -- now() et non une heure d'appareil : le téléphone du livreur n'est pas
  -- une source de temps de confiance.
  update public.colis_receipts set
    sender_name        = (select full_name from public.profiles where id = v_order.user_id),
    sender_phone       = coalesce(sender_phone, v_order.sender_phone),
    driver_id          = v_driver.id,
    driver_name        = v_name,
    driver_plate       = v_driver.vehicle_plate,
    pickup_photo_path  = p_photo_path,
    pickup_at          = now(),
    pickup_lat         = p_lat,
    pickup_lng         = p_lng,
    pickup_app_version = p_app_version,
    proof_status       = 'pickup_only'
  where order_id = p_order_id
  returning * into v_receipt;

  if v_receipt.order_id is null then
    raise exception 'Aucun bon de prise en charge pour la commande %', p_order_id;
  end if;

  return v_receipt;
end;
$fn$;


-- ── 10. Remise ─────────────────────────────────────────────────────────────
-- Vérifie le code (ou l'absence de code en mode no_code), enregistre la
-- preuve, puis passe la commande à 'delivered' — ce qui déclenche le trigger
-- de règlement existant, inchangé.

create or replace function public.colis_verify_and_deliver(
  p_order_id    uuid,
  p_code        text,
  p_photo_path  text,
  p_lat         double precision,
  p_lng         double precision,
  p_app_version text default null
) returns public.colis_receipts
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_driver   public.drivers%rowtype;
  v_order    public.orders%rowtype;
  v_receipt  public.colis_receipts%rowtype;
  v_hash     text;
  v_ref_hash text;
  v_dist     integer;
  v_dest_lat double precision;
  v_dest_lng double precision;
begin
  select * into v_driver from public.drivers where user_id = auth.uid();
  if v_driver.id is null then
    raise exception 'Seul un livreur peut enregistrer une remise';
  end if;

  select * into v_order from public.orders where id = p_order_id;
  if v_order.driver_id is distinct from v_driver.id then
    raise exception 'Cette commande n''est pas assignée à ce livreur';
  end if;
  if v_order.status = 'delivered' then
    raise exception 'Cette commande est déjà livrée';
  end if;

  select * into v_receipt from public.colis_receipts where order_id = p_order_id;
  if v_receipt.order_id is null then
    raise exception 'Aucun bon de prise en charge pour la commande %', p_order_id;
  end if;
  if v_receipt.pickup_at is null then
    raise exception 'La prise en charge doit être enregistrée avant la remise';
  end if;
  if coalesce(p_photo_path, '') = '' then
    raise exception 'La photo de remise est obligatoire';
  end if;
  if v_receipt.code_locked_at is not null then
    raise exception 'Trop de codes erronés : un administrateur doit intervenir';
  end if;

  if v_receipt.delivery_mode = 'code' then
    -- Le hash de référence est lu ici, en SECURITY DEFINER, dans une table
    -- que l'appelant ne peut pas lire lui-même.
    select code_hash into v_ref_hash
      from public.colis_delivery_codes where order_id = p_order_id;
    v_hash := encode(sha256(convert_to(coalesce(p_code, '') || p_order_id::text, 'UTF8')), 'hex');

    if v_ref_hash is null or v_hash is distinct from v_ref_hash then
      update public.colis_receipts
         set code_attempts = code_attempts + 1,
             code_locked_at = case when code_attempts + 1 >= 5 then now() else null end
       where order_id = p_order_id
      returning * into v_receipt;

      if v_receipt.code_locked_at is not null then
        -- Alerte admin. Best effort : support_tickets a pu gagner des
        -- colonnes que ce fichier ignore, et l'échec du code doit rester
        -- enregistré même si le ticket ne part pas.
        begin
          insert into public.support_tickets (user_id, subject, message, status)
          values (
            v_order.user_id,
            'Colis bloqué #' || upper(substring(p_order_id::text, 1, 8)),
            'Cinq codes erronés sur la commande ' || p_order_id::text
              || '. Livreur ' || coalesce(v_driver.id::text, '?')
              || '. Une clôture administrative est nécessaire.',
            'open'
          );
        exception when others then null;
        end;
        raise exception 'Code incorrect. Limite atteinte : un administrateur a été alerté';
      end if;

      raise exception 'Code incorrect (tentative % sur 5)', v_receipt.code_attempts;
    end if;
  else
    -- Mode sans code : la preuve est la photo et le GPS, et l'expéditeur
    -- l'a accepté explicitement à la commande.
    if coalesce(v_receipt.receiver_label, '') = '' then
      raise exception 'Le destinataire désigné est manquant sur ce colis';
    end if;
  end if;

  v_dest_lat := nullif(v_order.delivery_address->>'latitude', '')::double precision;
  v_dest_lng := nullif(v_order.delivery_address->>'longitude', '')::double precision;
  v_dist     := public.colis_distance_m(p_lat, p_lng, v_dest_lat, v_dest_lng);

  update public.colis_receipts set
    delivery_photo_path  = p_photo_path,
    delivery_at          = now(),
    delivery_lat         = p_lat,
    delivery_lng         = p_lng,
    delivery_distance_m  = v_dist,
    code_verified        = (v_receipt.delivery_mode = 'code'),
    delivery_app_version = p_app_version,
    proof_status         = 'complete'
  where order_id = p_order_id
  returning * into v_receipt;

  -- Déclenche generate_settlements_on_delivery, inchangé.
  update public.orders set status = 'delivered' where id = p_order_id;

  return v_receipt;
end;
$fn$;


-- ── 11. Clôture forcée par un admin ────────────────────────────────────────

create or replace function public.colis_admin_force_close(
  p_order_id uuid,
  p_reason   text
) returns public.colis_receipts
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_receipt public.colis_receipts%rowtype;
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true) then
    raise exception 'Réservé aux administrateurs';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'Un motif écrit est obligatoire';
  end if;

  -- code_verified n'est touché que si la remise n'a PAS encore été
  -- enregistrée : sur un reçu déjà complet, le trigger d'immuabilité
  -- refuserait la modification, et il aurait raison.
  update public.colis_receipts set
    admin_override_by     = auth.uid(),
    admin_override_reason = btrim(p_reason),
    admin_override_at     = now(),
    code_verified         = case when delivery_at is null then false else code_verified end,
    proof_status          = case when proof_status = 'complete' then proof_status else 'missing' end
  where order_id = p_order_id
  returning * into v_receipt;

  if v_receipt.order_id is null then
    raise exception 'Aucun bon de prise en charge pour la commande %', p_order_id;
  end if;

  update public.orders set status = 'delivered'
   where id = p_order_id and status <> 'delivered';

  return v_receipt;
end;
$fn$;


-- ── 12. Litige ─────────────────────────────────────────────────────────────
-- Ouvert par l'expéditeur, jusqu'à 24 h après delivered_at — y compris sur
-- une commande auto-confirmée au bout de 3 minutes, les deux mécanismes étant
-- indépendants. Un litige ne défait aucun règlement : un admin tranche.

create or replace function public.colis_open_dispute(
  p_order_id uuid,
  p_kind     text,
  p_message  text default null
) returns public.colis_disputes
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_order   public.orders%rowtype;
  v_dispute public.colis_disputes%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id;
  if v_order.id is null or v_order.user_id is distinct from auth.uid() then
    raise exception 'Commande introuvable';
  end if;
  if v_order.order_type <> 'courier' then
    raise exception 'Cette commande n''est pas un colis';
  end if;
  if p_kind not in ('not_received', 'parcel_problem') then
    raise exception 'Type de litige inconnu : %', p_kind;
  end if;
  if v_order.delivered_at is null then
    raise exception 'Cette commande n''a pas encore été livrée';
  end if;
  if v_order.delivered_at < now() - interval '24 hours' then
    raise exception 'Le délai de 24 heures pour signaler un problème est dépassé';
  end if;

  insert into public.colis_disputes (order_id, user_id, driver_id, kind, message)
  values (p_order_id, auth.uid(), v_order.driver_id, p_kind, nullif(btrim(coalesce(p_message, '')), ''))
  returning * into v_dispute;

  begin
    insert into public.support_tickets (user_id, subject, message, status)
    values (
      auth.uid(),
      'Litige colis #' || upper(substring(p_order_id::text, 1, 8)),
      'Litige (' || p_kind || ') sur la commande ' || p_order_id::text
        || coalesce(' — ' || nullif(btrim(coalesce(p_message, '')), ''), ''),
      'open'
    );
  exception when others then null;
  end;

  return v_dispute;
end;
$fn$;


-- ── 13. Droits d'exécution ─────────────────────────────────────────────────
-- SECURITY DEFINER sans revoke, c'est une porte ouverte : par défaut une
-- fonction est exécutable par PUBLIC, donc par anon.

revoke execute on function public.create_colis_order(jsonb, jsonb, text, text, text, text, numeric, numeric, text, text, text, text, timestamptz) from public, anon;
revoke execute on function public.colis_set_declaration(uuid, text, numeric, text, text) from public, anon;
revoke execute on function public.colis_record_pickup(uuid, text, double precision, double precision, text) from public, anon;
revoke execute on function public.colis_verify_and_deliver(uuid, text, text, double precision, double precision, text) from public, anon;
revoke execute on function public.colis_admin_force_close(uuid, text) from public, anon;
revoke execute on function public.colis_open_dispute(uuid, text, text) from public, anon;
revoke execute on function public.platform_setting(text) from public, anon;

grant execute on function public.create_colis_order(jsonb, jsonb, text, text, text, text, numeric, numeric, text, text, text, text, timestamptz) to authenticated;
-- PAS de grant sur colis_set_declaration : aucune app ne l'appelle, le
-- client cree sa commande et sa declaration d'un seul tenant via
-- create_colis_order. La fonction reste en place pour amender une
-- declaration avant la prise en charge ; le jour ou une app s'en sert,
-- il faudra ajouter le grant ici.
revoke execute on function public.colis_set_declaration(uuid, text, numeric, text, text) from authenticated;
grant execute on function public.colis_record_pickup(uuid, text, double precision, double precision, text) to authenticated;
grant execute on function public.colis_verify_and_deliver(uuid, text, text, double precision, double precision, text) to authenticated;
grant execute on function public.colis_admin_force_close(uuid, text) to authenticated;
grant execute on function public.colis_open_dispute(uuid, text, text) to authenticated;
-- PAS de grant sur platform_setting : elle n'est appelee que depuis des
-- SECURITY DEFINER, qui l'executent en tant que proprietaire. Le client
-- lit la TABLE platform_settings, pas cette fonction.
revoke execute on function public.platform_setting(text) from authenticated;


-- ── 14. Déploiement souple ─────────────────────────────────────────────────
-- Un APK livreur antérieur passe encore la commande à 'delivered' par un
-- UPDATE direct, sans preuve. En 'soft' on l'accepte et on marque le reçu
-- 'missing' ; en 'hard' on refuse. Le basculement est une ligne de
-- platform_settings, pas un redéploiement.

create or replace function public.colis_enforce_proof()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
declare
  v_mode    text;
  v_receipt public.colis_receipts%rowtype;
begin
  if new.order_type <> 'courier'
     or new.status <> 'delivered'
     or old.status = 'delivered' then
    return new;
  end if;

  select * into v_receipt from public.colis_receipts where order_id = new.id;
  if v_receipt.order_id is null or v_receipt.proof_status = 'complete' then
    return new;
  end if;

  -- Une clôture administrative passe toujours, y compris en 'hard' : c'est
  -- précisément la porte de sortie quand le code est perdu. Sans cette
  -- exception, le durcissement enfermerait l'admin lui-même.
  if v_receipt.admin_override_at is not null then
    return new;
  end if;

  v_mode := coalesce(public.platform_setting('colis_proof_enforcement'), 'soft');

  if v_mode = 'hard' then
    raise exception 'Preuve de remise manquante : photo et code sont obligatoires';
  end if;

  update public.colis_receipts
     set proof_status = 'missing'
   where order_id = new.id
     and proof_status <> 'complete';

  return new;
end;
$fn$;

-- Supabase accorde EXECUTE a anon/authenticated sur toute nouvelle fonction
-- du schema public (ALTER DEFAULT PRIVILEGES). Un `revoke from public` ne
-- retire PAS cet octroi nominatif : il faut nommer anon. Le revoke suit
-- immediatement la creation, car re-creer la fonction re-applique les
-- privileges par defaut.
revoke execute on function public.colis_enforce_proof() from public, anon, authenticated;

drop trigger if exists trg_colis_enforce_proof on public.orders;
create trigger trg_colis_enforce_proof
  before update of status on public.orders
  for each row execute function public.colis_enforce_proof();


-- ── 15. Stockage privé ─────────────────────────────────────────────────────
-- colis-proofs est privé dès le premier jour. package-photos passe en privé :
-- il contenait des photos de colis lisibles par quiconque avait l'URL.
-- Les apps devront servir ces images par URL signée.

-- package-photos n'est PAS touché ici : le basculer en privé casserait
-- l'affichage des photos dans les APK livreurs déjà installés, qui lisent
-- encore des URL publiques. Ce basculement vit dans
-- 20261012093000_package_photos_private.sql, à lancer APRÈS le déploiement
-- des nouveaux builds.
insert into storage.buckets (id, name, public)
  values ('colis-proofs', 'colis-proofs', false)
  on conflict (id) do update set public = false;

-- Chemin attendu : <order_id>/pickup.jpg et <order_id>/delivery.jpg, donc
-- le premier segment du nom porte l'identifiant de commande.
drop policy if exists colis_proofs_driver_insert on storage.objects;
create policy colis_proofs_driver_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'colis-proofs'
    and exists (
      select 1 from public.orders o
        join public.drivers d on d.id = o.driver_id
       where d.user_id = auth.uid()
         and o.id::text = split_part(name, '/', 1)
    )
  );

drop policy if exists colis_proofs_read on storage.objects;
create policy colis_proofs_read
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'colis-proofs'
    and (
      exists (select 1 from public.orders o
               where o.id::text = split_part(name, '/', 1)
                 and o.user_id = auth.uid())
      or exists (select 1 from public.orders o
                   join public.drivers d on d.id = o.driver_id
                  where d.user_id = auth.uid()
                    and o.id::text = split_part(name, '/', 1))
      or exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true)
    )
  );

-- Aucune policy UPDATE ni DELETE : une preuve déposée ne se remplace pas.


-- ── 16. Garde-fous avant COMMIT ────────────────────────────────────────────
do $$
declare n integer;
begin
  -- Le livreur ne doit avoir AUCUNE policy sur le code en clair.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_delivery_codes';
  if n <> 1 then
    raise exception 'Abandon : colis_delivery_codes porte % policies, une seule est attendue', n;
  end if;

  -- Le CIN non plus, ni le CIN vivant ni celui figé sur un reçu.
  select count(*) into n from pg_policies
   where schemaname = 'public'
     and tablename in ('driver_identity', 'colis_receipt_identity');
  if n <> 2 then
    raise exception 'Abandon : % policies sur les tables CIN, 2 attendues', n;
  end if;

  -- Et aucune de ces policies ne doit laisser passer autre chose qu un admin.
  select count(*) into n from pg_policies
   where schemaname = 'public'
     and tablename in ('driver_identity', 'colis_receipt_identity')
     and qual not like '%is_admin%';
  if n <> 0 then
    raise exception 'Abandon : % policy(s) CIN sans controle admin', n;
  end if;

  -- Aucune policy d'écriture directe sur le reçu : tout passe par les RPC.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_receipts'
     and cmd <> 'SELECT';
  if n <> 0 then
    raise exception 'Abandon : % policy(s) d ecriture directe sur colis_receipts', n;
  end if;

  -- AUCUN hash de code ne doit vivre dans une table que le livreur lit.
  -- 4 chiffres = 10 000 valeurs : un hash lisible se casse instantanement,
  -- et le code ne vaudrait plus rien. On verifie la colonne la ou elle ne
  -- doit pas etre, et la ou elle doit etre.
  select count(*) into n from information_schema.columns
   where table_schema = 'public'
     and column_name in ('delivery_code_hash', 'code_hash')
     and table_name <> 'colis_delivery_codes';
  if n <> 0 then
    raise exception 'Abandon : % colonne(s) de hash de code hors de colis_delivery_codes', n;
  end if;

  select count(*) into n from information_schema.columns
   where table_schema = 'public'
     and table_name = 'colis_delivery_codes'
     and column_name = 'code_hash';
  if n <> 1 then
    raise exception 'Abandon : colis_delivery_codes.code_hash est absente';
  end if;

  -- Et la table qui le porte reste sans acces livreur : une seule policy,
  -- celle de l expediteur et des admins.
  select count(*) into n from pg_policies
   where schemaname = 'public' and tablename = 'colis_delivery_codes'
     and qual like '%drivers%';
  if n <> 0 then
    raise exception 'Abandon : une policy de colis_delivery_codes mentionne les livreurs';
  end if;

  -- Le bucket de preuves est prive. package-photos est traite a part, apres
  -- le deploiement des nouveaux builds.
  select count(*) into n from storage.buckets
   where id = 'colis-proofs' and public;
  if n <> 0 then
    raise exception 'Abandon : le bucket colis-proofs est encore public';
  end if;

  -- Les quatre RPC existent et sont en SECURITY DEFINER.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and p.proname in ('create_colis_order', 'colis_set_declaration',
                       'colis_record_pickup', 'colis_verify_and_deliver',
                       'colis_admin_force_close', 'colis_open_dispute')
     and p.prosecdef;
  if n <> 6 then
    raise exception 'Abandon : % RPC en SECURITY DEFINER sur 6 attendues', n;
  end if;

  -- Aucune de ces RPC ne doit rester executable par anon.
  select count(*) into n from pg_proc p
    join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
     and (p.proname like 'colis\_%' or p.proname = 'create_colis_order')
     and has_function_privilege('anon', p.oid, 'execute');
  if n <> 0 then
    raise exception 'Abandon : % fonction(s) colis_* encore executables par anon', n;
  end if;

  -- Le plafond est bien en base et non codé en dur.
  if public.platform_setting('colis_max_declared_value') is null then
    raise exception 'Abandon : colis_max_declared_value absent de platform_settings';
  end if;
end
$$;

commit;
