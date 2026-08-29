CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(username text, is_valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_referrer_username text;
BEGIN
    SELECT p.username INTO v_referrer_username
    FROM public.profiles p
    WHERE lower(trim(p.referral_code)) = lower(trim(_code))
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    RETURN QUERY SELECT v_referrer_username, TRUE, ('Referrer found: ' || v_referrer_username)::text;
END;
$function$;