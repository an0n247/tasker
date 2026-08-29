-- Revoke public execution for handle_new_user
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated, anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;

-- Revoke public execution for reward_referrer_on_signup
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO postgres;
