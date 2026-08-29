CREATE OR REPLACE FUNCTION public.lookup_login_email(_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    user_email TEXT;
BEGIN
    IF _username IS NULL OR length(trim(_username)) = 0 THEN
        RETURN NULL;
    END IF;

    SELECT au.email INTO user_email
    FROM auth.users au
    JOIN public.profiles p ON p.id = au.id
    WHERE lower(p.username) = lower(trim(_username))
    LIMIT 1;

    RETURN user_email;
END;
$$;

REVOKE ALL ON FUNCTION public.lookup_login_email(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(TEXT) TO anon, authenticated, service_role;