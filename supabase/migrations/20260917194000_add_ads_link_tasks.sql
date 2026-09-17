-- Ads Link tasks require ten link clicks before the task is completed.
CREATE TABLE IF NOT EXISTS public.ads_link_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    click_count INTEGER NOT NULL DEFAULT 0,
    last_click_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, task_id)
);

ALTER TABLE public.ads_link_progress ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.ads_link_progress TO authenticated;
GRANT ALL ON public.ads_link_progress TO service_role;

CREATE POLICY "Users can view their own ads link progress"
    ON public.ads_link_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.record_ads_link_click(_user_id UUID, _task_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task RECORD;
    v_progress RECORD;
    v_required_clicks INTEGER := 10;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT id, title, category, link_url
      INTO v_task
    FROM public.tasks
    WHERE id = _task_id
      AND is_active = true
      AND category = 'Ads Link'
      AND NULLIF(TRIM(link_url), '') IS NOT NULL;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Ads Link task not found or inactive');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.task_submissions
        WHERE user_id = _user_id
          AND task_id = _task_id
          AND status IN ('verified', 'approved')
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed');
    END IF;

    INSERT INTO public.ads_link_progress (user_id, task_id, click_count, last_click_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET click_count = ads_link_progress.click_count + 1,
        last_click_at = v_now
    RETURNING * INTO v_progress;

    IF v_progress.click_count >= v_required_clicks THEN
        RETURN json_build_object(
            'success', true,
            'ready_to_claim', true,
            'click_count', v_progress.click_count,
            'required_clicks', v_required_clicks,
            'message', 'All ten ad clicks recorded. You can now claim your reward.'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'completed', false,
        'click_count', v_progress.click_count,
        'required_clicks', v_required_clicks,
        'message', format('Ad click recorded (%s/%s)', v_progress.click_count, v_required_clicks)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_ads_link_click(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_ads_link_click(UUID, UUID) TO authenticated, service_role;

-- Prevent direct claim attempts from bypassing the ten-click requirement.
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
  v_category text;
  v_ad_click_count integer;
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
    AND status IN ('verified', 'approved')
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';

  IF v_daily_count >= v_daily_limit THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Daily task limit reached (%s tasks max per day)', v_daily_limit)
    );
  END IF;

  SELECT is_repeatable, verification_required, points, category
  INTO v_is_repeatable, v_verification_required, v_points, v_category
  FROM public.tasks
  WHERE id = _task_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Task not found or inactive');
  END IF;

  IF v_category = 'Ads Link' THEN
    SELECT click_count
      INTO v_ad_click_count
    FROM public.ads_link_progress
    WHERE user_id = _user_id AND task_id = _task_id;

    IF COALESCE(v_ad_click_count, 0) < 10 THEN
      RETURN json_build_object(
        'success', false,
        'message', format('Click the ad link %s more times before claiming this reward', 10 - COALESCE(v_ad_click_count, 0))
      );
    END IF;
  END IF;

  SELECT status, (created_at AT TIME ZONE 'UTC')::date
  INTO v_existing_status, v_last_submission_date
  FROM public.task_submissions
  WHERE user_id = _user_id AND task_id = _task_id
  ORDER BY created_at DESC LIMIT 1;

  IF v_existing_status IN ('verified', 'approved') AND v_last_submission_date = (now() AT TIME ZONE 'UTC')::date THEN
    RETURN json_build_object('success', false, 'message', 'Task already completed today');
  END IF;
  IF v_existing_status IN ('verified', 'approved') AND NOT COALESCE(v_is_repeatable, false) THEN
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

  IF NOT COALESCE(v_verification_required, false) THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
    VALUES (_user_id, v_points, 'earn', 'Completed task: ' || (SELECT title FROM public.tasks WHERE id = _task_id), _task_id::text);
  END IF;

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
