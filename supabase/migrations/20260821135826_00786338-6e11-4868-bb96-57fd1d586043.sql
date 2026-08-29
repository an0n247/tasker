-- Fix the trigger functions if they were accidentally created as standard functions
-- or if they are missing entirely.

-- 1. update_points_balance_on_task_status_change
CREATE OR REPLACE FUNCTION public.update_points_balance_on_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only award points when status changes to 'verified'
    IF (TG_OP = 'UPDATE' AND OLD.status <> 'verified' AND NEW.status = 'verified') OR
       (TG_OP = 'INSERT' AND NEW.status = 'verified') THEN
        
        -- Get task points
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        SELECT NEW.user_id, t.points, 'earn', 'Completed task: ' || t.title
        FROM public.tasks t
        WHERE t.id = NEW.task_id;
        
    END IF;
    RETURN NEW;
END;
$$;

-- 2. log_task_status_change
CREATE OR REPLACE FUNCTION public.log_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status <> NEW.status) THEN
        INSERT INTO public.admin_audit_logs (target_table, target_id, action_type, old_data, new_data)
        VALUES ('task_submissions', NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
    END IF;
    RETURN NEW;
END;
$$;

-- 3. log_user_task_activity
CREATE OR REPLACE FUNCTION public.log_user_task_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Potential for logging user activity analytics here
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$;

-- 4. Re-attach triggers to task_submissions
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

-- 5. Final permissions check
REVOKE ALL ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role;

REVOKE ALL ON FUNCTION public.log_task_status_change() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role;

REVOKE ALL ON FUNCTION public.log_user_task_activity() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role;

-- 6. Update submit_task to NOT manually insert points
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- RATE LIMITING
    SELECT created_at INTO v_last_submission
    FROM public.task_submissions
    WHERE user_id = _user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_submission IS NOT NULL AND v_now - v_last_submission < interval '2 seconds' THEN
        RETURN json_build_object('success', false, 'message', 'Please wait a moment before submitting again.');
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text || _task_id::text));

    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found or inactive.');
    END IF;

    SELECT * INTO v_existing_submission FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id;
    
    IF FOUND THEN
        IF v_existing_submission.status = 'verified' THEN
            RETURN json_build_object('success', false, 'message', 'Task already completed.');
        ELSIF v_existing_submission.status = 'pending' THEN
            RETURN json_build_object('success', false, 'message', 'Task already under review.');
        END IF;
    END IF;

    -- Create submission - Trigger will handle point awarding
    INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
    VALUES (_user_id, _task_id, CASE WHEN v_task_record.verification_required THEN 'pending' ELSE 'verified' END, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE 
    SET status = EXCLUDED.status, created_at = v_now;
    
    IF v_task_record.verification_required THEN
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification.');
    ELSE
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_task_record.points || ' points awarded.', 'points', v_task_record.points);
    END IF;
END;
$$;

-- 7. Update record_video_watch to NOT manually insert points
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT * INTO v_task_record 
    FROM public.tasks 
    WHERE id = _task_id 
      AND is_active = true 
      AND category = 'Videos'
      AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.task_submissions 
        WHERE user_id = _user_id 
          AND task_id = _task_id 
          AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Atomic completion - Trigger will handle point awarding
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE 
        SET status = 'verified', created_at = v_now;
        
        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true, 
            'completed', true, 
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true, 
        'completed', false, 
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$$;
