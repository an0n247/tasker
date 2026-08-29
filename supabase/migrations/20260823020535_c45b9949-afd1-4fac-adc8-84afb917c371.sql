-- Hardening search_path for all SECURITY DEFINER functions to prevent search_path spoofing
-- and revoking public execute where appropriate.

-- 1. has_role(uuid, public.app_role)
ALTER FUNCTION public.has_role(uuid, public.app_role) SET search_path = public;

-- 2. handle_new_user()
ALTER FUNCTION public.handle_new_user() SET search_path = public, auth;

-- 3. claim_daily_reward(uuid)
ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;

-- 4. verify_task_submission(uuid, boolean, text)
ALTER FUNCTION public.verify_task_submission(uuid, boolean, text) SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO service_role;

-- 5. submit_task(uuid, uuid)
ALTER FUNCTION public.submit_task(uuid, uuid) SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;

-- 6. record_video_watch(uuid, uuid, uuid)
ALTER FUNCTION public.record_video_watch(uuid, uuid, uuid) SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated;

-- 7. handle_task_status_notification()
ALTER FUNCTION public.handle_task_status_notification() SET search_path = public;

-- 8. referral-related trigger functions
ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public;
ALTER FUNCTION public.handle_referral_reward_on_first_task() SET search_path = public;

-- 9. Fix the notifications insert policy mentioned in linter
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications" 
ON public.notifications 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);
