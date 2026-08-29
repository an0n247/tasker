-- Revoke execute from public on all security definer functions
REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM public, anon, authenticated;

-- Grant execute only to the roles that actually need them
GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(text) TO authenticated, anon; -- Needed for sign-in logic
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated, anon; -- Needed for referral tracking on landing page

-- The triggers handle_new_user and notify_on_points_transaction are called by the system (service_role)
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role;

-- claim_daily_reward is already restricted to authenticated in the previous turn
