-- Address SECURITY DEFINER linter warnings (0028 and 0029)
-- Revoke default execution from PUBLIC on all future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Revoke execute from PUBLIC for existing SECURITY DEFINER functions with correct signatures
REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.lookup_login_email(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC;

-- Re-grant specific permissions
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role;

-- Administrative functions
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role;

-- Trigger/Internal functions
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role;
