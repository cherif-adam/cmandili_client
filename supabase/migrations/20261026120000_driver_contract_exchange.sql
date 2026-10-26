-- ============================================================================
-- AMANA -- Le contrat circule dans l'appli entre l'admin et le livreur
--
-- NON EXECUTE. A lancer dans le SQL Editor apres 20261015190000.
--
-- Avant : tout se passait en presentiel. Le livreur remettait son contrat
-- signe et legalise, l'admin le scannait (driver_identity.contract_scan_path).
--
-- Maintenant :
--   1. l'admin ENVOIE le contrat (PDF) depuis le dashboard
--                         -> driver-contracts/to_sign/<driver_id>/<ts>.pdf
--   2. le livreur le telecharge dans l'appli, le signe et le fait legaliser
--      a la baladiya (la legalisation reste en personne : c'est la loi)
--   3. il RENVOIE une photo du contrat signe et tamponne depuis l'appli
--                         -> driver-contracts/signed/<driver_id>/<ts>.jpg
--   4. l'admin la regarde et VALIDE : la photo devient le scan du dossier
--      (driver_identity.contract_scan_path), ou REFUSE avec un motif.
--
-- Le critere de verification ne change pas (CIN + date de legalisation +
-- scan, driver_is_verified()). Cette migration ajoute le chemin par lequel le
-- scan arrive ; driver_identity reste admin-only.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================

begin;

-- ── 1. L'etat de l'echange, visible par le livreur ─────────────────────────
-- Table separee de driver_identity : le livreur doit voir ou en est SON
-- contrat, alors que driver_identity (CIN) lui reste invisible.

create table if not exists public.driver_contracts (
  driver_id     uuid primary key references public.drivers(id) on delete cascade,
  to_sign_path  text,
  sent_at       timestamptz,
  sent_by       uuid,
  signed_path   text,
  submitted_at  timestamptz,
  status        text not null default 'sent'
                check (status in ('sent', 'submitted', 'approved', 'rejected')),
  admin_note    text,
  reviewed_at   timestamptz,
  reviewed_by   uuid
);

alter table public.driver_contracts enable row level security;

-- Le livreur lit sa ligne, et seulement elle. Il n'ecrit jamais directement :
-- il passe par submit_signed_contract().
drop policy if exists driver_contracts_select_own on public.driver_contracts;
create policy driver_contracts_select_own
  on public.driver_contracts for select
  to authenticated
  using (driver_id in (select d.id from public.drivers d where d.user_id = auth.uid()));

drop policy if exists driver_contracts_admin_all_rows on public.driver_contracts;
create policy driver_contracts_admin_all_rows
  on public.driver_contracts for all
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_admin = true));


-- ── 2. Le stockage : le livreur ne touche qu'a SES deux dossiers ───────────
-- Le bucket reste prive, et la policy admin existante (driver_contracts_admin_all)
-- ne change pas. Les scans deposes par l'admin sont a la racine
-- (<driver_id>/<ts>) : to_sign/ et signed/ ne s'y melangent pas.

drop policy if exists driver_contracts_driver_read on storage.objects;
create policy driver_contracts_driver_read
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'driver-contracts'
    and (storage.foldername(name))[1] in ('to_sign', 'signed')
    and (storage.foldername(name))[2] in (
      select d.id::text from public.drivers d where d.user_id = auth.uid()
    )
  );

drop policy if exists driver_contracts_driver_upload on storage.objects;
create policy driver_contracts_driver_upload
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'driver-contracts'
    and (storage.foldername(name))[1] = 'signed'
    and (storage.foldername(name))[2] in (
      select d.id::text from public.drivers d where d.user_id = auth.uid()
    )
  );


-- ── 3. Le livreur renvoie son contrat signe ────────────────────────────────

create or replace function public.submit_signed_contract(p_path text)
returns void
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_driver uuid;
begin
  select d.id into v_driver from public.drivers d where d.user_id = auth.uid();
  if v_driver is null then
    raise exception 'not_a_driver';
  end if;

  -- Le chemin doit etre dans SON dossier signed/, et le fichier doit exister.
  if p_path is null or p_path not like 'signed/' || v_driver::text || '/%' then
    raise exception 'bad_path';
  end if;
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'driver-contracts' and o.name = p_path
  ) then
    raise exception 'file_missing';
  end if;

  update public.driver_contracts
     set signed_path  = p_path,
         submitted_at = now(),
         status       = 'submitted',
         admin_note   = null
   where driver_id = v_driver
     and status in ('sent', 'rejected', 'submitted');
  if not found then
    raise exception 'no_contract_to_sign';
  end if;
end
$$;

revoke all on function public.submit_signed_contract(text) from public, anon;
grant execute on function public.submit_signed_contract(text) to authenticated;

commit;
