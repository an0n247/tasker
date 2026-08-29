-- Convert views to SECURITY INVOKER (Postgres default)
ALTER VIEW public.user_ranks SET (security_invoker = on);
ALTER VIEW public.my_referrals_detailed SET (security_invoker = on);

-- Audit functions for excessive permissions
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;

REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role;
