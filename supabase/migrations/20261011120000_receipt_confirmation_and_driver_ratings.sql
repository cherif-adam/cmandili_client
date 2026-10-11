-- The customer confirms the order arrived, and rates the driver
-- ============================================================================
-- NOT EXECUTED. Review, then run it yourself (SQL editor).
--
-- Until now "delivered" was the driver's word alone: the driver taps
-- "Confirm delivery", the order is closed, and the customer is never asked.
-- This adds the customer's side, without changing what "delivered" does
-- (commissions, wallets and settlements still happen at that moment):
--
--   1. The driver marks the order delivered  -> orders.delivered_at is stamped.
--   2. The client app asks "Did you receive your order?"
--        Yes -> client_confirmation = 'confirmed'
--        No  -> client_confirmation = 'not_received' + a support ticket, so
--               the admin sees it in the existing Support list
--        no answer for 3 minutes -> 'auto_confirmed' (cron below)
--      An automatic confirmation can still be overturned by the customer
--      (they open the app later and the order never came); their own Yes or
--      No is final.
--   3. The customer rates the driver (1-5 stars + comment). The average and
--      the count are kept on the driver's row and shown in their profile.
--
-- The client and driver apps are written to do nothing until this has run:
-- delivered_at stays null for older orders, so no old order starts asking.
--
-- ── Why a function and not a plain UPDATE from the app ─────────────────────
-- aa_guard_orders_column_scope (20260703130000) rejects any column a role is
-- not whitelisted for, and it lets everything through when current_user is
-- not 'authenticated' / 'anon'. confirm_order_receipt() is SECURITY DEFINER,
-- so it runs as its owner and passes the guard, after checking for itself
-- that the caller owns the order. The same holds for the cron job.

begin;

-- ── 1. Order columns ───────────────────────────────────────────────────────
alter table public.orders
  add column if not exists delivered_at        timestamptz,
  add column if not exists client_confirmation text,
  add column if not exists client_confirmed_at timestamptz;

alter table public.orders
  drop constraint if exists orders_client_confirmation_check;
alter table public.orders
  add constraint orders_client_confirmation_check
  check (client_confirmation is null
         or client_confirmation in ('confirmed', 'not_received', 'auto_confirmed'));

-- Stamp the moment of delivery. Its own trigger rather than an edit to
-- handle_order_status_timestamps(), whose live definition this file cannot
-- see. Named zz_ so it fires AFTER aa_guard_orders_column_scope: BEFORE
-- triggers run in name order, and the guard compares OLD and NEW -- if this
-- ran first, the guard would see delivered_at "changed by the driver" and
-- reject the delivery.
create or replace function public.stamp_order_delivered_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'delivered'
     and old.status is distinct from 'delivered'
     and new.delivered_at is null then
    new.delivered_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists zz_stamp_order_delivered_at on public.orders;
create trigger zz_stamp_order_delivered_at
  before update of status on public.orders
  for each row
  execute function public.stamp_order_delivered_at();

-- ── 2. The customer's answer ───────────────────────────────────────────────
create or replace function public.confirm_order_receipt(
  p_order_id uuid,
  p_received boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_order public.orders%rowtype;
  v_state text := case when p_received then 'confirmed' else 'not_received' end;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.user_id is distinct from v_uid then
    raise exception 'order not found';
  end if;
  if v_order.status <> 'delivered' then
    raise exception 'order is not delivered yet';
  end if;
  -- The customer's own answer is final; only "nobody answered" can be changed.
  if v_order.client_confirmation in ('confirmed', 'not_received') then
    return v_order.client_confirmation;
  end if;

  update public.orders
     set client_confirmation = v_state,
         client_confirmed_at = now()
   where id = p_order_id;

  if not p_received then
    -- Best effort: the customer's answer above must be kept even if the
    -- ticket cannot be written (support_tickets may have grown columns this
    -- file does not know about).
    begin
      insert into public.support_tickets (user_id, subject, message, status)
      values (
        v_uid,
        'Commande non reçue #' || upper(substring(p_order_id::text, 1, 8)),
        'Le client déclare ne pas avoir reçu la commande ' || p_order_id::text
          || ' (marquée livrée par le livreur '
          || coalesce(v_order.driver_id::text, 'inconnu') || ' le '
          || coalesce(to_char(v_order.delivered_at at time zone 'Africa/Tunis',
                              'DD/MM/YYYY HH24:MI'), '?') || ').',
        'open'
      );
    exception when others then
      raise warning 'confirm_order_receipt: support ticket not created: %', sqlerrm;
    end;
  end if;

  return v_state;
end;
$$;

revoke execute on function public.confirm_order_receipt(uuid, boolean) from public, anon;
grant  execute on function public.confirm_order_receipt(uuid, boolean) to authenticated;

-- ── 3. No answer after 3 minutes ───────────────────────────────────────────
-- delivered_at is null on every order delivered before this file ran, so
-- nothing old is touched.
select cron.schedule(
  'orders_auto_confirm_receipt',
  '* * * * *',
  $job$
    update public.orders
       set client_confirmation = 'auto_confirmed',
           client_confirmed_at = now()
     where status = 'delivered'
       and client_confirmation is null
       and delivered_at is not null
       and delivered_at < now() - interval '3 minutes';
  $job$
);

-- ── 4. Driver ratings ──────────────────────────────────────────────────────
alter table public.drivers
  add column if not exists rating       numeric(3,2) not null default 0,
  add column if not exists review_count integer      not null default 0;

create table if not exists public.driver_ratings (
  id         uuid primary key default gen_random_uuid(),
  order_id   uuid not null unique references public.orders(id) on delete cascade,
  driver_id  uuid not null references public.drivers(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  rating     smallint not null check (rating between 1 and 5),
  comment    text,
  created_at timestamptz not null default now()
);

create index if not exists idx_driver_ratings_driver
  on public.driver_ratings (driver_id, created_at desc);

alter table public.driver_ratings enable row level security;

-- One rating per order, by the customer of that order, for the driver who
-- delivered it, once it is delivered. Re-derived from orders rather than
-- trusted from the request, like order_ratings.
drop policy if exists driver_ratings_insert_own_delivered on public.driver_ratings;
create policy driver_ratings_insert_own_delivered
  on public.driver_ratings for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.orders o
      where o.id = driver_ratings.order_id
        and o.user_id = auth.uid()
        and o.status = 'delivered'
        and o.driver_id = driver_ratings.driver_id
    )
  );

-- The customer sees their own rating; the driver sees the ratings they got.
drop policy if exists driver_ratings_select_own_or_driver on public.driver_ratings;
create policy driver_ratings_select_own_or_driver
  on public.driver_ratings for select
  to authenticated
  using (
    user_id = auth.uid()
    or driver_id in (select d.id from public.drivers d where d.user_id = auth.uid())
  );

-- No UPDATE/DELETE policy: a rating is written once.

create or replace function public.recompute_driver_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.drivers
     set rating = (
           select round(coalesce(avg(r.rating), 0), 2)
           from public.driver_ratings r
           where r.driver_id = new.driver_id
         ),
         review_count = (
           select count(*)
           from public.driver_ratings r
           where r.driver_id = new.driver_id
         )
   where id = new.driver_id;
  return new;
end;
$$;

-- A driver may update their own row (online switch, position), which would
-- include these two columns. Keep them out of reach: only the trigger above
-- (running as its owner) may change them.
create or replace function public.protect_driver_rating()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.rating       := old.rating;
    new.review_count := old.review_count;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_driver_rating on public.drivers;
create trigger protect_driver_rating
  before update on public.drivers
  for each row
  execute function public.protect_driver_rating();

drop trigger if exists on_driver_rating_insert on public.driver_ratings;
create trigger on_driver_rating_insert
  after insert on public.driver_ratings
  for each row
  execute function public.recompute_driver_rating();

commit;
