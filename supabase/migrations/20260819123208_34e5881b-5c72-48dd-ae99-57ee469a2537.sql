-- Fix security issues for handle_new_user
ALTER FUNCTION public.handle_new_user() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
