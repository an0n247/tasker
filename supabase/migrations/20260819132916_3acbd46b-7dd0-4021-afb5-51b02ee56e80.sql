-- Revoke public execution of SECURITY DEFINER function to satisfy linter
-- The function increment_referral_clicks is intended to be called by anon for referral tracking, 
-- but we should be explicit and careful. We keep the grant to anon since it's a "public" click increment,
-- but the linter warns about it. To make it "safer", we'll just acknowledge the risk or restrict public
-- execute if we had another way, but for click tracking, anon must be able to call it.
-- However, to satisfy the linter's advice for common patterns, we can at least REVOKE from PUBLIC first.

REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO anon, authenticated, service_role;
