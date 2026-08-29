-- Precise revocation based on verified signatures

REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;

REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;

REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role;

-- Re-granting lookup functions that MUST be anon for the app to work
-- (Linter will still flag these as warnings, but they are required)
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated, service_role;
