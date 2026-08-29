-- Ensure the trigger for profile completion exists and is correctly applied
-- This trigger will flip pending transactions to completed when a user fills their profile.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'on_profile_completion'
    ) THEN
        CREATE TRIGGER on_profile_completion
        AFTER UPDATE ON public.profiles
        FOR EACH ROW
        EXECUTE FUNCTION public.check_pending_referrals_on_update();
    END IF;
END $$;

-- Verify RLS and grants for the new logic
GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role;
