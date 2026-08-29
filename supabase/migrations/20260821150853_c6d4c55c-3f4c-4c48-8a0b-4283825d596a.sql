CREATE OR REPLACE FUNCTION public.has_completed_social_profile(_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_required text[];
  v_social text;
  v_profile record;
  v_value text;
BEGIN
  SELECT COALESCE(ARRAY(SELECT jsonb_array_elements_text(value::jsonb)), '{}')
    INTO v_required
  FROM public.app_settings
  WHERE key = 'welcome_bonus_required_socials';

  IF v_required IS NULL OR array_length(v_required, 1) IS NULL THEN
    RETURN true;
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
  IF NOT FOUND THEN RETURN false; END IF;

  FOREACH v_social IN ARRAY v_required LOOP
    EXECUTE format('SELECT %I FROM public.profiles WHERE id = $1', v_social || '_handle')
      INTO v_value USING _user_id;
    IF v_value IS NULL OR btrim(v_value) = '' THEN
      RETURN false;
    END IF;
  END LOOP;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.has_completed_social_profile(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

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
$function$;

CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
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
$function$;