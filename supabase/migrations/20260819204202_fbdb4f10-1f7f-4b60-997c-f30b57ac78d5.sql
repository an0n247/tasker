
-- Secure handle_admin_audit_log
ALTER FUNCTION public.handle_admin_audit_log() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM anon;
GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role;
-- Triggers will still work because they are owned by postgres and the function is SECURITY DEFINER
