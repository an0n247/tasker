-- Fixed ambiguous oid reference
DO $$ 
DECLARE 
    func_record RECORD;
BEGIN 
    FOR func_record IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    LOOP 
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.' || quote_ident(func_record.proname) || '(' || func_record.args || ') FROM PUBLIC';
    END LOOP;
END $$;

-- 2. Explicitly re-grant execution only to specific roles for necessary functions
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role;

-- 3. Re-grant trigger/admin functions
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role;
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role;

-- 4. Set search_path for all security definer functions
ALTER FUNCTION public.reward_referrer_on_signup() SET search_path = public;
ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public;
ALTER FUNCTION public.sync_points_balance() SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.has_role(uuid, app_role) SET search_path = public;
ALTER FUNCTION public.claim_welcome_bonus(uuid) SET search_path = public;
ALTER FUNCTION public.check_referral_code(text, uuid) SET search_path = public;
ALTER FUNCTION public.lookup_login_email(text) SET search_path = public;
ALTER FUNCTION public.assign_role(uuid, app_role) SET search_path = public;
ALTER FUNCTION public.remove_role(uuid, app_role) SET search_path = public;
ALTER FUNCTION public.handle_admin_audit_log() SET search_path = public;
ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public;
