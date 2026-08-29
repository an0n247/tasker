
-- Revoke execute from anon/authenticated for internal triggers and sync functions
-- These should only be executable by the system (service_role) or via triggers

REVOKE EXECUTE ON FUNCTION public.sync_points_balance_trigger() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM anon, authenticated;

-- Keep grants only where necessary for app functionality
-- lookup_login_email is needed for login (anon)
-- increment_referral_clicks is needed for public links (anon)
-- check_referral_code is needed for signup (anon)
