CREATE POLICY "Admins and moderators can insert tasks" ON public.tasks FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator'));
CREATE POLICY "Admins and moderators can update tasks" ON public.tasks FOR UPDATE TO authenticated USING (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator')) WITH CHECK (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator'));
CREATE POLICY "Admins can delete tasks" ON public.tasks FOR DELETE TO authenticated USING (public.has_role(auth.uid(),'admin'));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tasks TO authenticated;
GRANT ALL ON public.tasks TO service_role;