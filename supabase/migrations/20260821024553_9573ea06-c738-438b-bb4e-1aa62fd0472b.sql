-- Revoke PUBLIC execute rights on SECURITY DEFINER functions
-- This addresses the 0028_anon_security_definer_function_executable and 0029_authenticated_security_definer_function_executable warnings

-- Revoke from PUBLIC (both anon and authenticated)
REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.has_role(UUID, app_role) FROM PUBLIC;

-- Re-grant to specific roles where needed
-- has_role is used in RLS policies, so it needs to be executable by authenticated users
GRANT EXECUTE ON FUNCTION public.has_role(UUID, app_role) TO authenticated, service_role;

-- trigger functions only need to be executable by service_role/postgres
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role;

-- is_profile_complete is used by the trigger, but also by the client for UI logic
-- Grant execute to authenticated users for UI checks
GRANT EXECUTE ON FUNCTION public.is_profile_complete(UUID) TO authenticated, service_role;
