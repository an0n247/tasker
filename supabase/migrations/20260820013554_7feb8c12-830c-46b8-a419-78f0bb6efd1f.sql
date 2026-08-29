-- Hardening claim_welcome_bonus function with server-side social handle validation
-- and ensuring uniqueness/format for handles.

CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean and validate handles
    -- Removing @ if present to standardize
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- CHECK FOR SOCIAL HANDLES (REFEREE MUST COMPLETE THIS)
    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram at minimum) to be eligible for the bonus.');
    END IF;

    -- Basic format validation (alphanumeric and underscores usually for handles)
    IF NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format. Use only letters, numbers, and underscores.');
    END IF;
    
    IF NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format. Should be 5-32 characters (letters, numbers, underscores).');
    END IF;

    -- Prevent Duplicate Handles (ensure another profile doesn't have the same handle already verified/claimed)
    -- This prevents multiple accounts using the same social handles to claim bonuses.
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id != _user_id 
        AND has_claimed_welcome_bonus = true 
        AND (
            (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
            (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean)
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- Update handles to cleaned versions and mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        -- Check if referrer exists
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;