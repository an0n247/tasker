-- ==============================================================================
-- Migration: Define admin_revoke_task_submission function (with text/uuid cast fix)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_revoke_task_submission(
    _submission_id uuid,
    _admin_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sub public.task_submissions%ROWTYPE;
  v_task_title text;
  v_credited integer := 0;
BEGIN
  -- Verify admin privileges
  IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized. Admin privileges required.');
  END IF;

  -- Fetch submission
  SELECT * INTO v_sub FROM public.task_submissions WHERE id = _submission_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Submission not found');
  END IF;

  SELECT title INTO v_task_title FROM public.tasks WHERE id = v_sub.task_id;

  -- Check if points were credited in transactions table (explicit text casting to avoid text = uuid operator error)
  SELECT COALESCE(SUM(amount), 0) INTO v_credited
  FROM public.points_transactions
  WHERE user_id = v_sub.user_id 
    AND source_id::text = v_sub.id::text 
    AND status = 'completed';

  -- Fallback: if no source_id match but status was verified, get task points
  IF v_credited = 0 AND v_sub.status = 'verified' THEN
    SELECT COALESCE(points, 0) INTO v_credited FROM public.tasks WHERE id = v_sub.task_id;
  END IF;

  -- Reverse points transaction if points were previously credited
  IF v_credited > 0 THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, source_id, status)
    VALUES (
      v_sub.user_id,
      -v_credited,
      'adjust',
      'Reversed points for revoked task: ' || COALESCE(v_task_title, 'task'),
      v_sub.id::text,
      'completed'
    );
  END IF;

  -- Remove the submission so user can re-attempt the task
  DELETE FROM public.task_submissions WHERE id = _submission_id;

  -- Sync points balance
  BEGIN
    PERFORM public.sync_points_balance(v_sub.user_id);
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.profiles 
    SET points_balance = GREATEST(0, COALESCE(points_balance, 0) - v_credited)
    WHERE id = v_sub.user_id;
  END;

  -- Send user warning/notification
  BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    VALUES (
      v_sub.user_id,
      'Task reset: ' || COALESCE(v_task_title, 'Task'),
      COALESCE(NULLIF(_admin_note, ''), 'This task was reset by an admin and is available to complete again.')
        || CASE WHEN v_credited > 0 THEN ' ' || v_credited || ' points were removed.' ELSE '' END,
      'warning',
      jsonb_build_object('task_id', v_sub.task_id)
    );
  EXCEPTION WHEN OTHERS THEN
    -- Ignore notification error
  END;

  RETURN json_build_object(
    'success', true, 
    'points_removed', v_credited,
    'message', 'Task submission revoked and points reversed.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.admin_revoke_task_submission(uuid, text) TO authenticated, service_role;
