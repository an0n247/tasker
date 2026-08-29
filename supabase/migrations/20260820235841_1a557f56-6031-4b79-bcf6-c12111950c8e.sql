
-- Security hardening: Revoke public execute from sensitive functions
-- These will only be callable by service_role or specifically granted roles (handled in handler/middleware)

-- Functions meant for public access (auth, signup, etc.)
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated;

-- Admin functions (should only be callable if the user has admin role)
-- But DB-level EXECUTE grant is usually for the role, then the function body checks has_role.
-- Let's restrict EXECUTE to authenticated and rely on internal has_role checks for the body.
REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM public, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role;

-- User functions
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated;

-- Ensure internal/trigger functions are NOT executable by anyone but owner/service_role
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_task_status_change() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.log_user_task_activity() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.guard_profile_sensitive_columns() FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM public, anon, authenticated;
