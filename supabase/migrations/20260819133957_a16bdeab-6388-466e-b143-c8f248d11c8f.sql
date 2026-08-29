-- Secure the handle_new_user function properly
ALTER FUNCTION public.handle_new_user() SECURITY DEFINER;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;

-- Secure points transaction triggers if they exist
-- (Checking for common patterns based on previous messages)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'on_points_transaction') THEN
        ALTER FUNCTION public.on_points_transaction() SECURITY DEFINER;
        REVOKE ALL ON FUNCTION public.on_points_transaction() FROM PUBLIC;
        GRANT EXECUTE ON FUNCTION public.on_points_transaction() TO service_role;
        GRANT EXECUTE ON FUNCTION public.on_points_transaction() TO postgres;
    END IF;
END $$;
