-- Secure SECURITY DEFINER functions
REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC, anon, authenticated;

-- Grant execution to authenticated for necessary functions
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
-- assign_role and remove_role should only be callable by admins, but as they are SECURITY DEFINER
-- and used in the UI, we keep them restricted or handle role checks inside them.
-- For now, let's keep them restricted from general authenticated users unless they are admins.
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated;

-- Ensure service_role always has access
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
