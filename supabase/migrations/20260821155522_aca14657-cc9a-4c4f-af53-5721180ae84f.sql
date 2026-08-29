-- Final version of claim_welcome_bonus to strictly enforce one-time claiming
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_bonus_enabled boolean;
    v_referral_points_referrer integer;
    v_referral_points_referee integer;
    v_required_socials jsonb;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
    v_duplicate_id uuid;
BEGIN
    -- 1. Authorization check
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 2. Lock the profile record to prevent race conditions
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id FOR UPDATE;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    -- 3. Strict one-time check
    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'alreadyClaimed', true, 'message', 'Bonus already claimed');
    END IF;

    -- 4. Read settings from app_settings
    SELECT (value->>0)::boolean INTO v_bonus_enabled FROM public.app_settings WHERE key = 'welcome_bonus_enabled';
    SELECT (value->>0)::integer INTO v_referral_points_referee FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
    SELECT (value->>0)::integer INTO v_referral_points_referrer FROM public.app_settings WHERE key = 'welcome_bonus_amount_referrer';
    SELECT value INTO v_required_socials FROM public.app_settings WHERE key = 'welcome_bonus_required_socials';

    -- Defaults
    v_bonus_enabled := COALESCE(v_bonus_enabled, true);
    v_referral_points_referee := COALESCE(v_referral_points_referee, 50);
    v_referral_points_referrer := COALESCE(v_referral_points_referrer, 75);
    v_required_socials := COALESCE(v_required_socials, '["twitter", "telegram"]'::jsonb);

    IF NOT v_bonus_enabled THEN
        RETURN json_build_object('success', false, 'message', 'Welcome bonus program is currently disabled.');
    END IF;

    -- 5. Clean and validate handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Social eligibility check
    IF ('"twitter"'::jsonb <@ v_required_socials) AND (v_twitter_clean IS NULL OR v_twitter_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Twitter profile to be eligible.');
    END IF;

    IF ('"telegram"'::jsonb <@ v_required_socials) AND (v_telegram_clean IS NULL OR v_telegram_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Telegram profile to be eligible.');
    END IF;
    
    -- Format validation
    IF (v_twitter_clean IS NOT NULL AND v_twitter_clean != '') AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    IF (v_telegram_clean IS NOT NULL AND v_telegram_clean != '') AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- 6. Duplicate handle check (anti-fraud)
    SELECT id INTO v_duplicate_id FROM public.profiles 
    WHERE id != _user_id 
    AND has_claimed_welcome_bonus = true 
    AND (
        (twitter_handle IS NOT NULL AND v_twitter_clean IS NOT NULL AND twitter_handle = v_twitter_clean) OR
        (telegram_handle IS NOT NULL AND v_telegram_clean IS NOT NULL AND telegram_handle = v_telegram_clean)
    )
    LIMIT 1;

    IF v_duplicate_id IS NOT NULL THEN
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (_user_id, 'social_duplicate', 'high', jsonb_build_object(
            'duplicate_user_id', v_duplicate_id,
            'twitter', v_twitter_clean,
            'telegram', v_telegram_clean
        ));
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- 7. MARK AS CLAIMED FIRST to prevent concurrent double-credit
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- 8. Record transactions
    -- Referee credit
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- Referrer credit
    IF v_profile.referred_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

-- Ensure proper permissions
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO service_role;
