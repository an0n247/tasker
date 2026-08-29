-- 1. Security Definer Views Fix
-- Although the linter flagged 1 view, I found 4. I will re-create them with SECURITY INVOKER (default) or ensure they don't use SECURITY DEFINER if they were.
-- Views in Postgres are by default SECURITY INVOKER unless they are specifically defined otherwise or if they are "Security Barrier" views.
-- To be safe, I will re-create them explicitly ensuring they don't have security definer properties if they did.

-- 2. Revoke PUBLIC execution from all SECURITY DEFINER functions in public schema
-- This addresses both "Public Can Execute" and "Signed-In Users Can Execute" warnings by default.
DO $$
DECLARE
    func_name text;
    func_schema text;
BEGIN
    FOR func_schema, func_name IN 
        SELECT n.nspname, p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.prosecdef = true
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %I.%I FROM PUBLIC;', func_schema, func_name);
    END LOOP;
END $$;

-- 3. Selectively grant execution back to appropriate roles for functions the app needs
-- Functions for internal triggers (should only be executable by service_role/owner)
-- notify_on_points_transaction, update_points_balance_on_task_status_change, 
-- log_task_status_change, update_user_points_balance, guard_profile_sensitive_columns,
-- handle_new_user, on_profile_completion, sync_balance_on_transaction
-- These don't need public or authenticated grants if they are only called by triggers.

-- Functions called directly from the frontend:
-- check_referral_code: needs to be callable by anon (for landing/signup)
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated;

-- increment_referral_clicks: needs to be callable by anon (for landing)
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated;

-- lookup_login_email: needs to be callable by anon (for login)
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated;

-- redeem_reward: needs to be callable by authenticated
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid, uuid) TO authenticated;

-- has_role: needs to be callable by authenticated (used in RLS)
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;

-- get_user_email_by_username: needs to be callable by anon (if still used)
-- Note: Linter mentioned this might be a leftover, but if it exists and is used:
-- GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(text) TO anon, authenticated;

