DROP POLICY IF EXISTS "Admins and moderators can insert tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can select all tasks" ON public.tasks;

CREATE POLICY "Task staff can insert tasks"
ON public.tasks FOR INSERT TO authenticated
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can update tasks"
ON public.tasks FOR UPDATE TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
)
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can select all tasks"
ON public.tasks FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

DROP POLICY IF EXISTS "Admins and moderators can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Moderators can update task submissions" ON public.task_submissions;

CREATE POLICY "Task staff can select all submissions"
ON public.task_submissions FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can update submissions"
ON public.task_submissions FOR UPDATE TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
)
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

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
    public.has_role(auth.uid(), 'moderator') OR
    public.has_role(auth.uid(), 'task_manager') OR
    public.has_role(auth.uid(), 'tasker')
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