-- 1. Drop the incorrect versions of the functions
-- First, identify and drop the ones that return trigger but shouldn't, or are duplicates.
DROP FUNCTION IF EXISTS public.sync_points_balance(); -- The one that returns trigger
DROP FUNCTION IF EXISTS public.update_user_points_balance(); -- Redundant

-- 2. Make sure the correct version of sync_points_balance exists
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

-- 3. Ensure sync_points_balance_trigger is correctly calling it
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM public.sync_points_balance(OLD.user_id);
    ELSE
        PERFORM public.sync_points_balance(NEW.user_id);
        IF (TG_OP = 'UPDATE' AND OLD.user_id <> NEW.user_id) THEN
            PERFORM public.sync_points_balance(OLD.user_id);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Check for any other problematic functions
-- I noticed log_task_status_change, update_points_balance_on_task_status_change, 
-- and log_user_task_activity were fixed in the previous turn to be triggers.
-- Let's ensure no NON-trigger versions of them exist.
DROP FUNCTION IF EXISTS public.log_task_status_change(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.update_points_balance_on_task_status_change(uuid, uuid);
DROP FUNCTION IF EXISTS public.log_user_task_activity(uuid, uuid, text);

-- 5. Re-verify triggers on task_submissions
DROP TRIGGER IF EXISTS on_task_status_change ON public.task_submissions;
CREATE TRIGGER on_task_status_change
    AFTER UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_verified ON public.task_submissions;
CREATE TRIGGER on_task_submission_verified
    AFTER INSERT OR UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_points_balance_on_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_activity ON public.task_submissions;
CREATE TRIGGER on_task_submission_activity
    AFTER INSERT ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_user_task_activity();
