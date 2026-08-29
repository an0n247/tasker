-- Revoke EXECUTE from public/anon/authenticated on SECURITY DEFINER functions
-- that should only be called by system triggers.

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() FROM PUBLIC, anon, authenticated;

-- Ensure service_role can still execute them (though triggers usually run as owner)
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO service_role;
