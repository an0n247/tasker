ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_repeatable BOOLEAN DEFAULT false;

CREATE OR REPLACE VIEW public.user_daily_task_counts AS
SELECT 
    user_id, 
    COUNT(*) as daily_count
FROM 
    public.task_submissions
WHERE 
    status = 'verified' AND
    (created_at AT TIME ZONE 'GMT')::date = (CURRENT_DATE AT TIME ZONE 'GMT')
GROUP BY 
    user_id;

GRANT SELECT ON public.user_daily_task_counts TO authenticated;
GRANT SELECT ON public.user_daily_task_counts TO service_role;

-- Update submit_task to handle limits and repeatability
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
    v_last_submission_date date;
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

    -- Check task repeatable status and last submission
    SELECT is_repeatable INTO v_is_repeatable FROM public.tasks WHERE id = _task_id;
    
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

    -- Allow if rejected, or if repeatable and last completion was before today, or if new
    INSERT INTO public.task_submissions (user_id, task_id, status)
    VALUES (_user_id, _task_id, 'pending');
    
    RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
END;
$$;

-- Update record_video_watch to handle limits
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid, _session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
    v_consumed_id uuid;
    v_daily_count integer;
    v_existing_status text;
    v_last_submission_date date;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Verify session
    IF NOT EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND user_id = _user_id AND task_id = _task_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Invalid watch session.');
    END IF;

    -- Check daily limit
    SELECT COALESCE(daily_count, 0) INTO v_daily_count
    FROM public.user_daily_task_counts
    WHERE user_id = _user_id;

    IF v_daily_count >= 10 THEN
         RETURN json_build_object('success', false, 'message', 'Daily task limit reached (10 tasks max per day)');
    END IF;

    SELECT * INTO v_task_record FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos';

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    -- Atomically consume the session
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE id = _session_id AND consumed = false
    RETURNING id INTO v_consumed_id;

    IF v_consumed_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'This watch session was already used.');
    END IF;

    -- Record progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET watch_count = CASE 
            WHEN (video_ad_progress.last_watch_at AT TIME ZONE 'GMT')::date < (CURRENT_DATE AT TIME ZONE 'GMT')::date THEN 1
            ELSE video_ad_progress.watch_count + 1
        END,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now);

        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object('success', true, 'completed', true, 'points', v_task_record.points, 'message', 'Goal reached!');
    END IF;

    RETURN json_build_object('success', true, 'completed', false, 'watch_count', v_progress_record.watch_count, 'message', 'Progress updated.');
END;
$$;
