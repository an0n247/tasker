CREATE UNIQUE INDEX IF NOT EXISTS user_roles_one_role_per_user_idx ON public.user_roles (user_id);

DROP POLICY IF EXISTS "All authenticated users can read permissions" ON public.role_permissions;
CREATE POLICY "Users can read permissions for their own role"
ON public.role_permissions FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.role = role_permissions.role
  )
);

REVOKE INSERT, UPDATE, DELETE ON public.points_transactions FROM authenticated;
GRANT SELECT ON public.points_transactions TO authenticated;

REVOKE ALL ON public.video_watch_sessions FROM anon, authenticated;
GRANT ALL ON public.video_watch_sessions TO service_role;