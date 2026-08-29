CREATE OR REPLACE FUNCTION public.check_username_available(_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE lower(trim(_username)) = lower(trim(profiles.username))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated, service_role;
