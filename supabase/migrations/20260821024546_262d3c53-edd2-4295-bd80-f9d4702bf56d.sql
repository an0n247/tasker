-- Security Hardening for new referral functions

-- Revoke execute on new functions from public
REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM public;
REVOKE EXECUTE ON FUNCTION public.is_profile_complete(UUID) FROM public;
REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM public;

-- Grant execute to relevant roles
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(UUID) TO authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role, postgres;

-- Re-set search_path to be extra safe
ALTER FUNCTION public.reward_referrer_on_signup() SET search_path = public;
ALTER FUNCTION public.is_profile_complete(UUID) SET search_path = public;
ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public;
ALTER FUNCTION public.sync_points_balance() SET search_path = public;
