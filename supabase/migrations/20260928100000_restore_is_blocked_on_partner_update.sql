-- ============================================================================
-- CMANDILI -- Remettre la verification is_blocked sur orders_partner_update
--
-- NON EXECUTE. A relire, puis a lancer vous-meme.
--
-- ── CE QUI S'EST PASSE ─────────────────────────────────────────────────────
-- La policy a ete reecrite deux fois pour le meme motif -- ouvrir l'ecriture
-- aux categories generiques (fleurs, animalerie, patisserie, cadeaux,
-- electronique), que l'ancienne version excluait en filtrant sur
-- partner_type IN ('restaurant','supermarket').
--
--   20260925200000  ouvre aux categories generiques, GARDE is_blocked
--   20260926100000  ouvre aux categories generiques, PERD is_blocked
--
-- La seconde a ete appliquee le 26/09 et a donc efface la condition. Verifie
-- en base avant d'ecrire ce fichier : la policy live ne contient plus
-- is_blocked. Le commentaire en tete de 20260926100000 dit que les deux sont
-- "equivalent in effect" ; c'est precisement le seul point ou elles different.
--
-- CONSEQUENCE. enforce_prepaid_block pose toujours partners.is_blocked = true
-- quand le solde tombe a zero, mais plus rien ne lit ce drapeau sur ce chemin :
-- un partenaire a sec continue d'accepter et de faire avancer ses commandes.
-- Tout le modele prepaye ne gouverne plus rien. Mesure precedemment :
--
--     Boutique Nour  (bloque)   1 ligne
--     Texas food     (bloque)   1 ligne
--     Digital House  (actif)    1 ligne
--
-- ── CE QUE FAIT CE FICHIER ─────────────────────────────────────────────────
-- Reprend la formulation de 20260926100000 -- la comparaison en TEXT y est
-- mieux pensee que la mienne, elle ne peut pas lever 22P02 sur un entity_id
-- vide -- et y rajoute la seule ligne manquante.
--
-- coalesce() est indispensable : partners.is_blocked est NULLABLE (defaut
-- false, mais nullable). Sans lui, un partenaire dont le drapeau vaut NULL
-- ferait echouer le EXISTS et se retrouverait verrouille en silence, ce qui
-- serait exactement le genre de panne qu'on vient de passer deux jours a
-- traquer.
--
-- SEULE la policy UPDATE est concernee. orders_partner_select reste ouverte a
-- un partenaire bloque, et c'est voulu : il doit pouvoir consulter ses
-- commandes pour comprendre pourquoi il est arrete, et voir son solde.
-- Empecher la lecture ne protegerait rien et donnerait une application muette.
--
-- Idempotent -- rejouable sans effet de bord.
-- ============================================================================

begin;

drop policy if exists "orders_partner_update" on public.orders;

create policy "orders_partner_update"
  on public.orders for update
  to authenticated
  using (
    exists (
      select 1 from public.partners p
      where p.user_id = auth.uid()
        -- ── LA LIGNE PERDUE LE 26/09 ──────────────────────────────────────
        and coalesce(p.is_blocked, false) = false
        and p.entity_id::text <> ''
        and lower(p.entity_id::text) in (orders.restaurant_id::text, orders.supermarket_id::text)
    )
  )
  with check (
    exists (
      select 1 from public.partners p
      where p.user_id = auth.uid()
        and coalesce(p.is_blocked, false) = false
        and p.entity_id::text <> ''
        and lower(p.entity_id::text) in (orders.restaurant_id::text, orders.supermarket_id::text)
    )
  );

-- Garde-fou : refuser de valider si la condition n'est pas reellement posee.
do $$
declare n integer;
begin
  select count(*) into n
  from pg_policies
  where schemaname = 'public' and tablename = 'orders'
    and policyname = 'orders_partner_update'
    and coalesce(qual, '') like '%is_blocked%'
    and coalesce(with_check, '') like '%is_blocked%';
  if n <> 1 then
    raise exception 'Abandon : orders_partner_update ne verifie pas is_blocked des deux cotes';
  end if;
end
$$;

commit;

-- ── Verification ───────────────────────────────────────────────────────────
-- Un partenaire actif doit pouvoir ecrire, un partenaire bloque non. Test en
-- transaction annulee, cote client :
--
--   supabase db query --linked --file supabase/scripts/20260928_verify_partner_block.sql
