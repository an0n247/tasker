
-- Revoke PUBLIC execute permissions from all SECURITY DEFINER functions in public schema
-- This addresses linter warnings 0028 and 0029.

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
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC', 
            func_record.nspname, func_record.proname, func_record.args);
    END LOOP;
END $$;

-- Selectively grant back only what is needed for authenticated users
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated;

-- Allow anon to lookup emails (for login) and increment clicks (public referral links)
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon;

-- Ensure service_role has all permissions
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Fix the analytics_events RLS policy
-- Note: 'qual' is for USING, which doesn't apply to INSERT. Only WITH CHECK is needed.
DROP POLICY IF EXISTS "Allow anyone to insert events" ON public.analytics_events;
CREATE POLICY "Allow authenticated to insert their own events" 
ON public.analytics_events
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow anon to log events (e.g., landing page visits) but only with NULL user_id
CREATE POLICY "Allow anon to insert anonymous events"
ON public.analytics_events
FOR INSERT
TO anon
WITH CHECK (user_id IS NULL);
