-- Function to update points_balance on profile when a transaction occurs
CREATE OR REPLACE FUNCTION public.update_user_points_balance()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.profiles
        SET points_balance = points_balance + NEW.amount
        WHERE id = NEW.user_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount
        WHERE id = OLD.user_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount + NEW.amount
        WHERE id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;

-- Add trigger to points_transactions table
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;
CREATE TRIGGER on_points_transaction_change
AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_user_points_balance();

-- One-time sync to ensure all balances are correct based on transaction history
UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(amount)
    FROM public.points_transactions
    WHERE user_id = p.id
), 0);

-- Revoke public execute on the trigger function
REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM public;
GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role;
