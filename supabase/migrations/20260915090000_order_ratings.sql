-- ============================================================================
-- CMANDILI -- Minimal post-delivery rating (food orders only)
--
-- One rating per delivered food order: 1-5 stars + optional comment.
-- Write-once by product decision -- no UPDATE/DELETE policy, so a customer
-- who mis-taps simply can't re-rate that order. restaurants.rating/
-- review_count are recomputed as a full aggregate on every insert rather
-- than incrementally -- simplest correct option at this data volume, and it
-- can never drift out of sync with the raw order_ratings rows the way a
-- running-average formula could.
--
-- Scope decision (mirrors the Reorder feature shipped in the same client
-- release): food orders only. Supermarket/courier/facture orders don't rate
-- a `restaurants` row and are out of scope here.
--
-- The INSERT policy re-derives eligibility from public.orders itself
-- (ownership, delivered status, food type, AND that restaurant_id actually
-- matches that order's own restaurant_id) rather than trusting any of the
-- client-submitted values -- a customer can only ever rate their own,
-- actually-delivered, actually-that-restaurant's food order.
--
-- PG15-safe + idempotent (DO $$ pg_policies guard, no CREATE POLICY IF NOT
-- EXISTS).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.order_ratings (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id       UUID NOT NULL UNIQUE REFERENCES public.orders(id),
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id  UUID NOT NULL REFERENCES public.restaurants(id),
  rating         SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment        TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_ratings_restaurant ON public.order_ratings(restaurant_id);

ALTER TABLE public.order_ratings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'order_ratings' AND policyname = 'order_ratings_select_own'
  ) THEN
    CREATE POLICY "order_ratings_select_own" ON public.order_ratings
      FOR SELECT USING (user_id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'order_ratings' AND policyname = 'order_ratings_insert_own_delivered'
  ) THEN
    CREATE POLICY "order_ratings_insert_own_delivered" ON public.order_ratings
      FOR INSERT
      WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
          SELECT 1 FROM public.orders o
          WHERE o.id = order_ratings.order_id
            AND o.user_id = auth.uid()
            AND o.status = 'delivered'
            AND o.order_type = 'food'
            AND o.restaurant_id = order_ratings.restaurant_id
        )
      );
  END IF;
END $$;

-- No UPDATE/DELETE policy: ratings are write-once by product decision above.


-- ── Trigger: recompute restaurants.rating / review_count on every new rating ─

CREATE OR REPLACE FUNCTION public.recompute_restaurant_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.restaurants
     SET rating = (
           SELECT COALESCE(AVG(rating), 0) FROM public.order_ratings
           WHERE restaurant_id = NEW.restaurant_id
         ),
         review_count = (
           SELECT COUNT(*) FROM public.order_ratings
           WHERE restaurant_id = NEW.restaurant_id
         )
   WHERE id = NEW.restaurant_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_rating_insert ON public.order_ratings;
CREATE TRIGGER on_order_rating_insert
AFTER INSERT ON public.order_ratings
FOR EACH ROW
EXECUTE FUNCTION public.recompute_restaurant_rating();
