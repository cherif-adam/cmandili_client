-- ============================================================================
-- CMANDILI -- Wire partners.is_blocked into actual enforcement
--
-- Problem: partners.is_blocked has existed since 20260628_partners_is_blocked
-- and is auto-set by enforce_prepaid_block() (20260805121032) when a
-- partner's wallet balance goes to/below zero -- but nothing ever checked it.
-- Not in the partner app, not in the client app's ordering flow, not in any
-- RLS policy. Confirmed live 2026-09-19: 8 of 11 active restaurants carry
-- is_blocked=true with zero functional effect -- a partner who owes
-- commission can keep scanning/adding menu items and accepting orders
-- exactly like one who doesn't.
--
-- Separate, more serious issue found while fixing the above: food_items and
-- grocery_items each carry a *second*, unscoped set of INSERT/UPDATE/DELETE
-- policies (food_items_insert/update/delete, grocery_items_insert/
-- update/delete) whose only check is `auth.role() = 'authenticated'` -- no
-- ownership check at all. Permissive policies OR together (see
-- 20260703120000's own lesson on this), so as long as these exist, ANY
-- signed-in user -- any customer, any driver, any other restaurant's
-- partner -- can write to ANY restaurant's or supermarket's menu,
-- completely bypassing "Partners can manage food/grocery items" below.
-- Adding an is_blocked check to only the scoped policy would have been
-- silently defeated by these, so they're dropped here as a prerequisite,
-- not scope creep -- confirmed via live rolled-back test (see test C).
--
-- Scope decision: this gates WRITES (menu insert/update/delete, order
-- confirm/accept), not login or visibility. profiles.is_blocked (the
-- actually-enforced login gate) is left untouched -- several accounts in
-- this project wear multiple hats (customer+driver, partner+admin), and
-- tying a commission-balance hold to full account lockout would also cut
-- off unrelated activity under the same login. A blocked partner can still
-- log in, see their dashboard/orders, and see why they're blocked.
--
-- Verified via a rolled-back DO-block harness before writing this file:
-- non-blocked partner still inserts/confirms on their own restaurant (PASS),
-- blocked partner can no longer do either (PASS), and an unrelated
-- authenticated customer can no longer insert into another restaurant's
-- menu (PASS -- confirms the bypass-policy removal actually closes the hole).
-- ============================================================================

-- ── food_items: drop the unscoped bypass policies ──────────────────────────
DROP POLICY IF EXISTS "food_items_insert" ON public.food_items;
DROP POLICY IF EXISTS "food_items_update" ON public.food_items;
DROP POLICY IF EXISTS "food_items_delete" ON public.food_items;

-- ── food_items: the real ownership policy now also requires not-blocked ────
ALTER POLICY "Partners can manage food items" ON public.food_items
USING (
  EXISTS (
    SELECT 1 FROM partners
    WHERE partners.entity_id = food_items.restaurant_id
      AND partners.user_id = auth.uid()
      AND partners.is_blocked = false
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM partners
    WHERE partners.entity_id = food_items.restaurant_id
      AND partners.user_id = auth.uid()
      AND partners.is_blocked = false
  )
);

-- ── grocery_items: same pattern, same pre-existing bypass ──────────────────
DROP POLICY IF EXISTS "grocery_items_insert" ON public.grocery_items;
DROP POLICY IF EXISTS "grocery_items_update" ON public.grocery_items;
DROP POLICY IF EXISTS "grocery_items_delete" ON public.grocery_items;

ALTER POLICY "Partners can manage grocery items" ON public.grocery_items
USING (
  EXISTS (
    SELECT 1 FROM partners
    WHERE partners.entity_id = grocery_items.supermarket_id
      AND partners.user_id = auth.uid()
      AND partners.is_blocked = false
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM partners
    WHERE partners.entity_id = grocery_items.supermarket_id
      AND partners.user_id = auth.uid()
      AND partners.is_blocked = false
  )
);

-- ── orders: block a blocked partner from confirming/progressing orders ─────
-- orders_partner_update is the only partner-scoped UPDATE policy on orders
-- (no unscoped OR'd bypass exists for it, unlike food_items above), so this
-- one change is sufficient to gate order-accept. Same entity_id::text
-- regex guard as the live policy (partners.entity_id is UUID live but TEXT
-- in the schema file -- see 20260703130000's note on this).
ALTER POLICY "orders_partner_update" ON public.orders
USING (
  (restaurant_id IN (
    SELECT (partners.entity_id)::text::uuid
    FROM partners
    WHERE partners.user_id = auth.uid()
      AND partners.partner_type = 'restaurant'
      AND partners.is_blocked = false
      AND (partners.entity_id)::text ~ '^[0-9a-f-]{36}$'
  ))
  OR (supermarket_id IN (
    SELECT (partners.entity_id)::text::uuid
    FROM partners
    WHERE partners.user_id = auth.uid()
      AND partners.partner_type = 'supermarket'
      AND partners.is_blocked = false
      AND (partners.entity_id)::text ~ '^[0-9a-f-]{36}$'
  ))
)
WITH CHECK (
  (restaurant_id IN (
    SELECT (partners.entity_id)::text::uuid
    FROM partners
    WHERE partners.user_id = auth.uid()
      AND partners.partner_type = 'restaurant'
      AND partners.is_blocked = false
      AND (partners.entity_id)::text ~ '^[0-9a-f-]{36}$'
  ))
  OR (supermarket_id IN (
    SELECT (partners.entity_id)::text::uuid
    FROM partners
    WHERE partners.user_id = auth.uid()
      AND partners.partner_type = 'supermarket'
      AND partners.is_blocked = false
      AND (partners.entity_id)::text ~ '^[0-9a-f-]{36}$'
  ))
);
