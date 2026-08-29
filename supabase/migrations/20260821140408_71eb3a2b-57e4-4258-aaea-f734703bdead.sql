-- 1. Redefine sync_points_balance as a normal function (NOT a trigger function)
-- This avoids the "trigger functions can only be called as triggers" error when called via PERFORM.
CREATE OR REPLACE FUNCTION public.sync_points_balance(p_user_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = p_user_id AND status = 'completed'
    )
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Redefine the trigger function to be a proper ROW trigger function that calls the normal function.
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM public.sync_points_balance(OLD.user_id);
    ELSE
        PERFORM public.sync_points_balance(NEW.user_id);
        
        -- If it's an update and user_id changed (rare but possible), sync the old one too
        IF (TG_OP = 'UPDATE' AND OLD.user_id <> NEW.user_id) THEN
            PERFORM public.sync_points_balance(OLD.user_id);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Re-attach the trigger as a ROW trigger (it was incorrectly attached as a STATEMENT trigger in some migrations)
DROP TRIGGER IF EXISTS sync_balance_on_transaction ON public.points_transactions;
CREATE TRIGGER sync_balance_on_transaction
    AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_points_balance_trigger();

-- 4. Remove the other potentially conflicting/redundant trigger if it exists
-- This one was also doing balance updates but without status checks.
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;

-- 5. Ensure permissions
GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.sync_points_balance_trigger() TO service_role;
