-- Drop existing function with old signature to allow changing return type
DROP FUNCTION IF EXISTS public.check_referral_code(text, uuid);

-- Re-defining the function with standardized parameters and return types
CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, message text) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_username text;
BEGIN
    -- 1. Find referrer
    SELECT p.username INTO v_referrer_username
    FROM public.profiles p
    WHERE p.referral_code = _code
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    -- 2. Success
    RETURN QUERY SELECT v_referrer_username, TRUE, 'Valid referral code.'::text;
END;
$$;

-- Explicitly grant execute permission
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon;