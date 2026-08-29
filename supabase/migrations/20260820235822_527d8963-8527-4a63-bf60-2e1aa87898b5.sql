
-- Revoke extra access to avoid leakage if RLS is bypassed or accidentally disabled
REVOKE ALL ON public.user_roles FROM public, anon, authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

-- Hardening RLS on user_roles: only user can see own role, admin can see all
DROP POLICY IF EXISTS "Admins can read all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can read their own roles" ON public.user_roles;

CREATE POLICY "Admins can select all roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can select their own roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Ensure profiles are secure
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
CREATE POLICY "Admins can select all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));

-- Ensure rewards are secure
DROP POLICY IF EXISTS "Admins can manage rewards" ON public.rewards;
CREATE POLICY "Admins can manage rewards"
ON public.rewards FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Hardening app_settings
DROP POLICY IF EXISTS "Allow admin to manage settings" ON public.app_settings;
CREATE POLICY "Admins can manage settings"
ON public.app_settings FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));
