CREATE OR REPLACE FUNCTION public.admin_revoke_task_submission(_submission_id uuid, _admin_note text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sub public.task_submissions%ROWTYPE;
  v_task_title text;
  v_credited integer;
BEGIN
  IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT * INTO v_sub FROM public.task_submissions WHERE id = _submission_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Submission not found');
  END IF;

  SELECT title INTO v_task_title FROM public.tasks WHERE id = v_sub.task_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_credited
  FROM public.points_transactions
  WHERE user_id = v_sub.user_id AND source_id = v_sub.id AND status = 'completed';

  IF v_credited <> 0 THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, source_id, status)
    VALUES (v_sub.user_id, -v_credited, 'adjust',
            'Reversed points for revoked task: ' || COALESCE(v_task_title, 'task'),
            v_sub.id, 'completed');
  END IF;

  DELETE FROM public.task_submissions WHERE id = _submission_id;

  PERFORM public.sync_points_balance(v_sub.user_id);

  PERFORM public.send_user_notification(
    v_sub.user_id,
    'Task reset: ' || COALESCE(v_task_title, 'Task'),
    COALESCE(NULLIF(_admin_note, ''), 'This task was reset by an admin and is available to complete again.')
      || CASE WHEN v_credited <> 0 THEN ' ' || v_credited || ' points were removed.' ELSE '' END,
    'warning',
    jsonb_build_object('task_id', v_sub.task_id)
  );

  RETURN json_build_object('success', true, 'points_removed', v_credited);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_revoke_task_submission(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_task_submission(uuid, text) TO authenticated;