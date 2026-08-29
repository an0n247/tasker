-- Security Hardening: Revoke broad permissions on SECURITY DEFINER functions

-- 1. Revoke PUBLIC execution on ALL functions in public schema as a baseline
-- We use a DO block to execute this as it might not be a single statement in all environments,
-- and it helps us handle the 'REVOKE' in a scriptable way.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 2. Grant EXECUTE to 'anon' for functions required during pre-auth/sign-up
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;

-- 3. Grant EXECUTE to 'authenticated' for user-facing actions
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated;

-- 4. Admin functions (explicitly grant only to authenticated, but has_role check is inside)
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated;

-- 5. Trigger functions (grant to service_role)
GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role;
GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role;
GRANT EXECUTE ON FUNCTION public.guard_profile_sensitive_columns() TO service_role;
GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance_trigger() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;
