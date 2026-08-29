DROP FUNCTION IF EXISTS public.check_username_available(text);
DROP FUNCTION IF EXISTS public.check_referral_code(text);
DROP FUNCTION IF EXISTS public.check_referral_code(text, uuid);

CREATE OR REPLACE FUNCTION public.check_username_available(_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE lower(trim(_username)) = lower(trim(p.username))
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_username text;
BEGIN
    SELECT p.username
    INTO v_referrer_username
    FROM public.profiles p
    WHERE p.referral_code = _code
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY
        SELECT NULL::text, false, 'Referral code not found.'::text;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT v_referrer_username, true, 'Valid referral code.'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role;
