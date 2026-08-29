-- Fix submit_task to honor verification_required setting
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing_status text;
    v_daily_count integer;
    v_is_repeatable boolean;
    v_verification_required boolean;
    v_last_submission_date date;
    v_points integer;
BEGIN
    -- Security check
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Check daily limit (count verified tasks today)
    SELECT COALESCE(daily_count, 0) INTO v_daily_count
    FROM public.user_daily_task_counts
    WHERE user_id = _user_id;

    IF v_daily_count >= 10 THEN
        RETURN json_build_object('success', false, 'message', 'Daily task limit reached (10 tasks max per day)');
    END IF;

    -- Check task details
    SELECT is_repeatable, verification_required, points 
    INTO v_is_repeatable, v_verification_required, v_points 
    FROM public.tasks 
    WHERE id = _task_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found');
    END IF;

    -- Check existing submissions
    SELECT status, (created_at AT TIME ZONE 'GMT')::date 
    INTO v_existing_status, v_last_submission_date
    FROM public.task_submissions
    WHERE user_id = _user_id AND task_id = _task_id
    ORDER BY created_at DESC LIMIT 1;

    -- If verified today, can't do it again
    IF v_existing_status = 'verified' AND v_last_submission_date = (CURRENT_DATE AT TIME ZONE 'GMT')::date THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed today');
    END IF;

    -- If verified previously and NOT repeatable, can't do it again
    IF v_existing_status = 'verified' AND NOT v_is_repeatable THEN
        RETURN json_build_object('success', false, 'message', 'This task can only be completed once');
    END IF;

    IF v_existing_status = 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Task already pending verification');
    END IF;

    -- Insert submission with correct status based on verification requirement
    INSERT INTO public.task_submissions (user_id, task_id, status)
    VALUES (
        _user_id, 
        _task_id, 
        CASE WHEN v_verification_required THEN 'pending'::text ELSE 'verified'::text END
    )
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET status = EXCLUDED.status, created_at = now();
    
    IF v_verification_required THEN
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
    ELSE
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_points || ' points awarded.', 'points', v_points);
    END IF;
END;
$$;

-- Grant EXECUTE to authenticated users for admin processing
GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated;
