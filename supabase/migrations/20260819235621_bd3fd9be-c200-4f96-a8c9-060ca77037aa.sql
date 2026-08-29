-- 1. Add the column to track if the bonus was claimed
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_claimed_welcome_bonus BOOLEAN DEFAULT FALSE;

-- 2. Create the referral code check function (using a different name for the boolean column to avoid reserved keyword 'exists')
CREATE OR REPLACE FUNCTION public.check_referral_code(_code TEXT)
RETURNS TABLE (username TEXT, is_valid BOOLEAN) 
LANGUAGE plpgsql SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    RETURN QUERY 
    SELECT p.username, TRUE 
    FROM public.profiles p 
    WHERE p.referral_code = _code
    LIMIT 1;
END;
$$;

-- 3. Create the claim welcome bonus function
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referred_by UUID;
    v_has_claimed BOOLEAN;
BEGIN
    -- Check if user exists and has a referrer
    SELECT referred_by, has_claimed_welcome_bonus 
    INTO v_referred_by, v_has_claimed
    FROM public.profiles
    WHERE id = _user_id;

    IF v_referred_by IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not eligible for a referral bonus.');
    END IF;

    IF v_has_claimed THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bonus already claimed.');
    END IF;

    -- Update profile
    UPDATE public.profiles
    SET has_claimed_welcome_bonus = TRUE
    WHERE id = _user_id;

    RETURN jsonb_build_object('success', true, 'message', 'Bonus claimed successfully!', 'amount', 50);
END;
$$;

-- 4. Set permissions
REVOKE ALL ON FUNCTION public.check_referral_code(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT) TO service_role;
