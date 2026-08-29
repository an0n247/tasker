-- 1. Fix mutable search_path on the task submission notification trigger
ALTER FUNCTION public.notify_on_task_submission() SET search_path = public;

-- 2. Make analytics views run with the querying user's permissions (security invoker)
ALTER VIEW public.daily_task_completions SET (security_invoker = true);
ALTER VIEW public.repeatable_task_stats SET (security_invoker = true);

-- 3. Replace the open notification-insert path with a validated SECURITY DEFINER function
CREATE OR REPLACE FUNCTION public.send_user_notification(
  _user_id uuid,
  _title text,
  _message text,
  _type text DEFAULT 'system',
  _metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only admins and moderators may send notifications to other users
  IF auth.uid() IS NULL OR (
    NOT public.has_role(auth.uid(), 'admin') AND
    NOT public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: insufficient privileges';
  END IF;

  -- Prevent abuse via oversized payloads
  IF char_length(_title) > 200 OR char_length(_message) > 2000 THEN
    RAISE EXCEPTION 'Notification content too long';
  END IF;

  IF char_length(_type) > 50 THEN
    RAISE EXCEPTION 'Invalid notification type';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id) THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type, metadata)
  VALUES (_user_id, _title, _message, _type, _metadata);

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) TO authenticated;

-- Remove the permissive policy that let any user insert notifications for anyone
DROP POLICY IF EXISTS "Users can insert notifications for others during system actions" ON public.notifications;

-- 4. Narrow moderator access on task_submissions: no more full ALL (no DELETE of history)
DROP POLICY IF EXISTS "Admins and moderators can manage task submissions" ON public.task_submissions;

CREATE POLICY "Admins can manage task submissions"
ON public.task_submissions
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Moderators can update task submissions"
ON public.task_submissions
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'moderator'))
WITH CHECK (public.has_role(auth.uid(), 'moderator'));