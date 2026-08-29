-- Harden record_video_watch with security best practices
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
    -- SECURITY CHECK: Only the user themselves can record a watch
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 1. Get task details - must be active, video category, and have a valid ad count
    SELECT * INTO v_task_record 
    FROM public.tasks 
    WHERE id = _task_id 
      AND is_active = true 
      AND category = 'Videos'
      AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    -- 2. Check if already completed
    IF EXISTS (
        SELECT 1 FROM public.task_submissions 
        WHERE user_id = _user_id 
          AND task_id = _task_id 
          AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- 3. Update or insert progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    -- 4. Check if finished
    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Atomic completion
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE 
        SET status = 'verified', created_at = v_now;
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed video task: ' || v_task_record.title, v_now);
        
        -- Clean up progress table (optional, but keeps it tidy)
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

-- Ensure permissions are correctly set
REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO service_role;
