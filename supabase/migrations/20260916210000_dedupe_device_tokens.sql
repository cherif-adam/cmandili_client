-- ============================================================================
-- CMANDILI -- Stop device_tokens from accumulating stale rows per user
--
-- Problem: _registerToken() (identical in all three mobile apps' push_service.dart)
-- does `upsert(..., onConflict: 'token')`. That only deduplicates when the exact
-- same token string comes back -- a fresh install, a `flutter run` rebuild, or
-- Firebase rotating a token all produce a NEW token value, which just gets
-- INSERTed as an extra row rather than replacing the user's previous one.
--
-- Confirmed live (2026-09-16): 6 accounts had accumulated duplicates, from as
-- far back as May -- client@gmail.com had 6 rows, texas@gmail.com 4,
-- drive@gmail.com 4, seven@gmail.com and piccolomondo@gmail.com and
-- adem@gmail.com 2 each. When two stale-but-still-valid tokens exist for the
-- same physical device, push-on-order-status sends the same push to both;
-- Android's own per-app anti-spam logic then mutes whichever copy of the
-- alarm notification lands second, which is what made the new-order sound on
-- the partner and driver apps feel inconsistent rather than reliably absent
-- or reliably present.
--
-- Fix: dedupe down to one row per (user_id, platform) -- keeping the most
-- recently updated token, deterministic tie-break on the token value itself
-- for the vanishingly unlikely case of two identical updated_at values -- then
-- add a UNIQUE constraint so a future re-registration UPDATEs that one row
-- (via the matching onConflict target in the app-side upsert, see the
-- accompanying push_service.dart changes) instead of accumulating another.
-- `token` stays the primary key -- unrelated, still enforces global
-- uniqueness of the token string itself.
-- ============================================================================

DELETE FROM public.device_tokens
WHERE token IN (
  SELECT token FROM (
    SELECT token,
           ROW_NUMBER() OVER (
             PARTITION BY user_id, platform
             ORDER BY updated_at DESC, token DESC
           ) AS rn
    FROM public.device_tokens
  ) ranked
  WHERE rn > 1
);

ALTER TABLE public.device_tokens
  ADD CONSTRAINT device_tokens_user_platform_unique UNIQUE (user_id, platform);
