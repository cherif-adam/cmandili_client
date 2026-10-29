-- ============================================================================
-- CMANDILI / Amana — Corriger les règlements écrits deux fois
--
-- Version validée le 29/10 (sans reprise de la subvention). À lancer dans le
-- SQL Editor APRÈS 20261029130000_driver_release_order, qui ajoute le type
-- 'correction' : le script refuse de tourner sinon.
--
-- 3 commandes ont vu tous leurs règlements écrits deux fois (une commande
-- revenue à 'delivered'). On ne supprime rien : chaque copie de commission
-- reçoit une écriture inverse de type 'correction', liée à la même commande,
-- qui remet le portefeuille au bon montant (trigger update_wallet_balance).
--
--   commande  date   compte (rôle)                    copie      montant   correction
--   9ff9e204  26/09  33187181 (Boutique Nour)          ba94140f   -15.400   +15.400
--   9ff9e204  26/09  fe291537 (livreur)                8ca9a683    -0.805    +0.805
--   3200cf0a  09/10  e26a024a (Texas food)             db2910b3    -4.400    +4.400
--   3200cf0a  09/10  8fbe55e5 (livreur)                25c5a2db    -0.403    +0.403
--   3200cf0a  09/10  8fbe55e5 (livreur) subvention     230edd79    +1.348    aucune (*)
--   bfcdb882  11/10  e26a024a (Texas food)             c0b29bc1    -1.400    +1.400
--   bfcdb882  11/10  59b8262a (livreur)                eb416549    -0.805    +0.805
--
-- (*) La subvention fidélité payée deux fois au livreur 8fbe55e5 (1.348 DT)
--     n'est pas reprise : la plateforme la garde à sa charge. La reprendre
--     ferait passer son solde de 0.740 à -0.205 DT et enforce_prepaid_block
--     le bloquerait.
--
-- Rejouable : une copie déjà corrigée ne l'est pas deux fois.
-- ============================================================================

begin;

do $check$
begin
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.settlements'::regclass and conname = 'settlements_type_check'
                    and pg_get_constraintdef(oid) like '%correction%') then
    raise exception 'Lancer d''abord 20261029130000_driver_release_order : le type correction n''existe pas encore';
  end if;
end
$check$;

insert into public.settlements (user_id, entity_type, amount, type, description, related_order_id, status)
select s.user_id, s.entity_type, -s.amount, 'correction',
       'Annulation du doublon ' || left(s.id::text, 8) || ' (' || s.description || ')',
       s.related_order_id, 'paid'
  from public.settlements s
 where s.id = any ('{ba94140f-ee22-41f9-9fe9-1d2d2f65a751,
                     8ca9a683-ee8c-452e-99ff-f20cc9a69e38,
                     db2910b3-02a8-4cb2-8a4d-a13ae596b578,
                     25c5a2db-7b81-4573-83da-b44a42affc64,
                     c0b29bc1-eb18-426a-ac40-899629707caa,
                     eb416549-642c-4bae-8658-5ae9a5ce1ec3}'::uuid[])
   and not exists (select 1 from public.settlements c
                    where c.type = 'correction'
                      and c.description like 'Annulation du doublon ' || left(s.id::text, 8) || '%');

commit;

-- ── Vérification ───────────────────────────────────────────────────────────
-- Attendu : 6 corrections ; soldes Boutique Nour (33187181) 19.200,
-- Texas food (e26a024a) 32.790, livreurs fe291537 250.196, 59b8262a 50.516,
-- 8fbe55e5 1.143.
select (select count(*) from public.settlements where type = 'correction') as corrections,
       (select json_object_agg(left(user_id::text, 8), balance) from public.wallets
         where user_id in ('33187181-c146-41bf-8dfb-83e68ddc1fb7', 'e26a024a-23a4-489e-ad34-91e925ea8b23',
                           'fe291537-4377-41da-a9a3-2065eaca1912', '59b8262a-06d6-4bbd-9d66-dc10942188e7',
                           '8fbe55e5-11d8-47aa-a3da-884803a8c8c6')) as soldes;
