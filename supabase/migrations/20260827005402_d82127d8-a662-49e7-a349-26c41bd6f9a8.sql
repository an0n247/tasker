CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_status text;
  v_daily_count integer;
  v_daily_limit integer := 10;
  v_is_repeatable boolean;
  v_verification_required boolean;
  v_last_submission_date date;
  v_points integer;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT COALESCE(
    CASE
      WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
      WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
      ELSE NULL
    END,
    10
  )
  INTO v_daily_limit
  FROM public.app_settings
  WHERE key = 'daily_task_limit'
  LIMIT 1;
  v_daily_limit := GREATEST(COALESCE(v_daily_limit, 10), 1);

  SELECT count(*) INTO v_daily_count
  FROM public.task_submissions
  WHERE user_id = _user_id
    AND status = 'verified'
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';

  IF v_daily_count >= v_daily_limit THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Daily task limit reached (%s tasks max per day)', v_daily_limit)
    );
  END IF;

  SELECT is_repeatable, verification_required, points
  INTO v_is_repeatable, v_verification_required, v_points
  FROM public.tasks
  WHERE id = _task_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Task not found or inactive');
  END IF;

  SELECT status, (created_at AT TIME ZONE 'UTC')::date
  INTO v_existing_status, v_last_submission_date
  FROM public.task_submissions
  WHERE user_id = _user_id AND task_id = _task_id
  ORDER BY created_at DESC LIMIT 1;

  IF v_existing_status = 'verified' AND v_last_submission_date = (now() AT TIME ZONE 'UTC')::date THEN
    RETURN json_build_object('success', false, 'message', 'Task already completed today');
  END IF;
  IF v_existing_status = 'verified' AND NOT COALESCE(v_is_repeatable, false) THEN
    RETURN json_build_object('success', false, 'message', 'This task can only be completed once');
  END IF;
  IF v_existing_status = 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Task already pending verification');
  END IF;

  INSERT INTO public.task_submissions (user_id, task_id, status, admin_note, verified_at)
  VALUES (
    _user_id,
    _task_id,
    CASE WHEN COALESCE(v_verification_required, false) THEN 'pending' ELSE 'verified' END,
    NULL,
    CASE WHEN COALESCE(v_verification_required, false) THEN NULL ELSE now() END
  )
  ON CONFLICT (user_id, task_id) DO UPDATE
  SET status = EXCLUDED.status,
      created_at = now(),
      admin_note = NULL,
      verified_at = EXCLUDED.verified_at;

  IF COALESCE(v_verification_required, false) THEN
    RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Task completed! ' || v_points || ' points awarded.',
    'points', v_points
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role;