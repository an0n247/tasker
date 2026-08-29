ALTER TABLE public.task_submissions
  ADD COLUMN IF NOT EXISTS admin_note text,
  ADD COLUMN IF NOT EXISTS verified_at timestamp with time zone;

CREATE OR REPLACE FUNCTION public.verify_task_submission(
  _submission_id uuid,
  _approve boolean,
  _admin_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission public.task_submissions%ROWTYPE;
  v_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR
    public.has_role(auth.uid(), 'moderator')
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT * INTO v_submission
  FROM public.task_submissions
  WHERE id = _submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission not found');
  END IF;

  IF v_submission.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission has already been processed');
  END IF;

  v_status := CASE WHEN _approve THEN 'verified' ELSE 'rejected' END;

  UPDATE public.task_submissions
  SET status = v_status,
      admin_note = NULLIF(btrim(_admin_note), ''),
      verified_at = now()
  WHERE id = _submission_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN _approve THEN 'Task approved successfully' ELSE 'Task rejected' END,
    'status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_task_submission(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
  p_target_user_id uuid,
  p_amount integer,
  p_action_type text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_transaction_id uuid;
  v_final_amount integer;
BEGIN
  IF v_admin_id IS NULL OR NOT public.has_role(v_admin_id, 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
  END IF;
  IF p_action_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Invalid points action';
  END IF;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;
  IF NULLIF(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'A reason is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  v_final_amount := CASE WHEN p_action_type = 'credit' THEN p_amount ELSE -p_amount END;

  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (p_target_user_id, v_final_amount, 'adjustment', 'Admin adjustment: ' || btrim(p_reason), 'completed')
  RETURNING id INTO v_transaction_id;

  INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
  VALUES (p_target_user_id, v_final_amount, 'Admin Adjustment: ' || btrim(p_reason), 'manual_admin_action');

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
  VALUES (v_admin_id, 'points_adjustment', 'profiles', p_target_user_id,
    jsonb_build_object('amount', v_final_amount, 'reason', btrim(p_reason), 'transaction_id', v_transaction_id));
END;
$$;

REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role;

ALTER TABLE public.admin_audit_logs DROP CONSTRAINT IF EXISTS admin_audit_logs_action_type_check;
ALTER TABLE public.admin_audit_logs ADD CONSTRAINT admin_audit_logs_action_type_check CHECK (
  action_type IN (
    'INSERT', 'UPDATE', 'DELETE', 'points_adjustment', 'role_change',
    'status_change', 'auto_fraud_flag', 'referral_reward', 'task_verification'
  )
);

CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  granularity text DEFAULT 'day',
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE(completion_date date, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF granularity NOT IN ('day', 'week', 'month') THEN
    granularity := 'day';
  END IF;
  RETURN QUERY
  SELECT date_trunc(granularity, ts.created_at)::date, count(*)
  FROM public.task_submissions ts
  WHERE ts.status = 'verified'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR ts.task_id = filter_task_id)
  GROUP BY 1 ORDER BY 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE(id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT t.id, t.title, count(ts.id), count(DISTINCT ts.user_id),
    round(count(ts.id)::numeric / nullif(count(DISTINCT ts.user_id), 0), 2)
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE t.is_repeatable = true
    AND ts.status = 'verified'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR t.id = filter_task_id)
  GROUP BY t.id, t.title;
END;
$$;

REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, text, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.sync_points_balance(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO service_role;

INSERT INTO public.app_settings (key, value, description)
VALUES ('daily_task_limit', '10'::jsonb, 'Maximum tasks a user may complete per day')
ON CONFLICT (key) DO NOTHING;

UPDATE public.role_permissions
SET is_enabled = CASE
  WHEN tab_name IN ('tasks', 'verifications', 'approvals') THEN true
  ELSE false
END
WHERE role = 'moderator';