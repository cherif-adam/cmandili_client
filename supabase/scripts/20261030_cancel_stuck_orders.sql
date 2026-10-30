-- ============================================================================
-- CMANDILI / Amana — Fermer les 3 commandes restées vides le 30/10
--
-- À lancer dans le SQL Editor (projet cmandili), APRÈS
-- 20261030120000_order_items_legacy_mirror.sql.
--
-- Le 30/10 entre 15:39 et 15:43 UTC, « Commander » chez Charlot a créé 3
-- commandes dont les articles ont été refusés (order_items_food_item_id_fkey) :
-- elles sont restées « pending » sans aucun article. Ce sont les seules
-- commandes sans article depuis le 22/09 (hors coursier et factures, qui n'en
-- ont jamais). Toutes les 3 viennent du même compte client, en espèces.
--
-- Ce script :
--   - ne touche que ces 3 ids ;
--   - s'arrête sans rien changer si l'une d'elles a un article ;
--   - annule celles encore « pending » (cancelled_by = 'system', motif
--     « Articles non enregistrés (bug du 30/10) ») ; le trigger d'annulation
--     rend au client la récompense fidélité (moitié prix) utilisée par la
--     première ; le client reçoit une notification « ... is now cancelled »
--     par commande ;
--   - laisse telles quelles celles déjà fermées : la tâche automatique annule
--     toute commande sans activité depuis 60 minutes (passages de 16:40 et
--     16:45 UTC le 30/10). Dans ce cas il n'y a plus rien à faire, et le
--     script le dit.
-- ============================================================================

begin;

do $cancel$
declare
  ids constant uuid[] := array['2811497e-d750-45ef-906c-aa9b90d7c14b',
                               '97987e45-443b-4bce-9282-476fb599ca0c',
                               '3c70a86f-1c22-4c9f-9086-e42853b41f31']::uuid[];
  n integer;
begin
  select count(*) into n from public.orders where id = any (ids);
  if n <> 3 then
    raise exception 'Attendu 3 commandes, trouvé % : rien n''est changé', n;
  end if;

  select count(*) into n from public.order_items where order_id = any (ids);
  if n > 0 then
    raise exception '% article(s) sur ces commandes : elles ne sont pas vides, rien n''est changé', n;
  end if;

  update public.orders
     set status = 'cancelled',
         cancelled_by = 'system',
         cancellation_reason = 'Articles non enregistrés (bug du 30/10)',
         cancelled_at = now()
   where id = any (ids)
     and status = 'pending';
  get diagnostics n = row_count;
  raise notice '% commande(s) annulée(s) par ce script ; % déjà fermée(s) avant', n, 3 - n;
end
$cancel$;

commit;

-- ── Vérification (à lire après l'exécution) ─────────────────────────────────
-- Attendu : 3 lignes, statut = cancelled, articles = 0, et pour motif
-- « Articles non enregistrés (bug du 30/10) », ou « Annulée automatiquement :
-- aucune activité pendant 60 minutes. » si la tâche automatique est passée avant.
select o.id, o.created_at, o.status, o.cancelled_by, o.cancellation_reason as motif, o.cancelled_at,
       (select count(*) from public.order_items oi where oi.order_id = o.id) as articles
  from public.orders o
 where o.id in ('2811497e-d750-45ef-906c-aa9b90d7c14b', '97987e45-443b-4bce-9282-476fb599ca0c',
                '3c70a86f-1c22-4c9f-9086-e42853b41f31')
 order by o.created_at;
