-- Ensure the profile completion trigger is correctly linked to the profile updates
-- This automation ensures that once a user fills their details, all pending rewards are flipped to positive.

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

-- Hardening the balance synchronization to ensure dashboards update instantly
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.sync_points_balance();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sync_balance_on_transaction') THEN
        CREATE TRIGGER sync_balance_on_transaction
        AFTER INSERT OR UPDATE ON public.points_transactions
        FOR EACH STATEMENT
        EXECUTE FUNCTION public.sync_points_balance_trigger();
    END IF;
END $$;
