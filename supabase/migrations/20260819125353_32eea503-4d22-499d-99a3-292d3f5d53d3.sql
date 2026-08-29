-- Final attempt to satisfy linter by being extremely explicit about revoking from everyone including public
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL PRIVILEGES ON FUNCTION public.handle_new_user() FROM authenticated, anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;
