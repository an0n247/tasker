ALTER TABLE public.task_submissions
  ADD CONSTRAINT task_submissions_user_id_profiles_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
  NOT VALID;

ALTER PUBLICATION supabase_realtime ADD TABLE public.task_submissions;
ALTER TABLE public.task_submissions REPLICA IDENTITY FULL;