-- 1. Revoke PUBLIC execution from all SECURITY DEFINER functions in public schema
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.prosecdef = true
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC;', func_record.nspname, func_record.proname, func_record.args);
    END LOOP;
END $$;

-- 2. Selectively grant execution back to appropriate roles
-- Public/Auth functions for core features
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated;

-- Auth-only functions for user actions
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated;

-- Admin-only functions
-- These will be checked via internal logic (like has_role) but we grant execute to authenticated
-- so the Data API can call them, then the function body enforces the admin check.
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO authenticated;
