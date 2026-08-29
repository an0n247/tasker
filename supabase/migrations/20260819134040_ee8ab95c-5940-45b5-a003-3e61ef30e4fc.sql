CREATE OR REPLACE FUNCTION public.get_user_email_by_username(_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT au.email INTO user_email
    FROM auth.users au
    JOIN public.profiles p ON p.id = au.id
    WHERE p.username = _username;
    
    RETURN user_email;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_email_by_username(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(TEXT) TO authenticated, anon, service_role;
