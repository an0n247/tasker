
REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(text) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, authenticated, anon;
-- handle_new_user is a trigger, usually executed by the system or a service role, 
-- but we'll at least restrict PUBLIC/anon.
