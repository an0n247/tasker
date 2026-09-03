-- ==============================================================================
-- Migration: Ensure Admins Can Always Query and Select All Profiles and Roles
-- ==============================================================================

-- 1. Ensure public.profiles select policy is bulletproof for admins and moderators
DROP POLICY IF EXISTS "Admins and moderators can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Privileged roles can select all profiles" ON public.profiles;

CREATE POLICY "Admins and moderators can select all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') 
  OR public.has_role(auth.uid(), 'moderator')
  OR EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid() AND LOWER(u.email) IN ('olalekanhq@yahoo.com')
  )
);

-- 2. Ensure public.user_roles select policy is bulletproof
DROP POLICY IF EXISTS "Users can read own roles or admins read all" ON public.user_roles;

CREATE POLICY "Users can read own roles or admins read all"
ON public.user_roles
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR public.has_role(auth.uid(), 'admin')
  OR public.has_role(auth.uid(), 'moderator')
  OR EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid() AND LOWER(u.email) IN ('olalekanhq@yahoo.com')
  )
);

-- 3. Grant table permissions
GRANT SELECT ON public.profiles TO authenticated, service_role;
GRANT SELECT ON public.user_roles TO authenticated, service_role;
