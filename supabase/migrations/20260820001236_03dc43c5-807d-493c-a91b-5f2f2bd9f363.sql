-- Secure the check_referral_code function
REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role;

-- System triggers
REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- Reward function
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role;
