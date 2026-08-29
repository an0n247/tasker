-- Fixing security linter warnings

-- 1. Fix search_path and execution for notify_on_points_transaction
ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role;

-- 2. Fix search_path and execution for has_role (already has search_path, just execution)
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO service_role;

-- 3. Fix handle_new_user from previous migration
ALTER FUNCTION public.handle_new_user() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- 4. Ensure RLS policies exist for user_roles (missed in migration)
CREATE POLICY "Admins can read all roles" ON public.user_roles
    FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can read their own roles" ON public.user_roles
    FOR SELECT TO authenticated USING (auth.uid() = user_id);
