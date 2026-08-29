-- 1. Add fingerprint and last_ip to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fingerprint text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_ip text;

-- 2. Create fraud_flags table
CREATE TABLE IF NOT EXISTS public.fraud_flags (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    type text NOT NULL, -- 'multi_account', 'self_referral', 'suspicious_activity', 'social_duplicate'
    severity text DEFAULT 'medium', -- 'low', 'medium', 'high'
    details jsonb,
    status text DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fraud_flags TO authenticated;
GRANT ALL ON public.fraud_flags TO service_role;

ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all fraud flags"
ON public.fraud_flags
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- 3. Update handle_new_user to include basic fraud detection
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    new_username text;
    base_username text;
    counter integer := 0;
    v_referrer_id uuid;
    v_fingerprint text;
    v_ip text;
BEGIN
    -- Extract username from metadata or email
    base_username := COALESCE(
        new.raw_user_meta_data->>'username',
        split_part(new.email, '@', 1)
    );
    
    -- Clean base_username (remove invalid characters)
    base_username := regexp_replace(base_username, '[^a-zA-Z0-9_]', '', 'g');
    
    -- Ensure username is not empty after cleaning
    IF base_username = '' THEN
        base_username := 'user_' || substr(new.id::text, 1, 8);
    END IF;

    -- Ensure unique username
    new_username := base_username;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = new_username AND id != new.id) LOOP
        counter := counter + 1;
        new_username := base_username || counter::text;
    END LOOP;

    -- Extract fraud detection markers
    v_fingerprint := new.raw_user_meta_data->>'fingerprint';
    v_ip := new.raw_user_meta_data->>'ip_address';

    -- Resolve referrer_id from metadata
    v_referrer_id := (
        SELECT id FROM public.profiles 
        WHERE username = COALESCE(
            new.raw_user_meta_data->>'referral_code_used',
            new.raw_user_meta_data->>'referral_code'
        )
        LIMIT 1
    );

    -- Insert or Update profile
    INSERT INTO public.profiles (
        id, 
        email,
        username, 
        full_name, 
        avatar_url,
        referral_code,
        referred_by,
        fingerprint,
        last_ip
    )
    VALUES (
        new.id, 
        new.email,
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username,
        v_referrer_id,
        v_fingerprint,
        v_ip
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url,
        referred_by = EXCLUDED.referred_by,
        fingerprint = COALESCE(EXCLUDED.fingerprint, profiles.fingerprint),
        last_ip = COALESCE(EXCLUDED.last_ip, profiles.last_ip);

    -- Record in referrals table if referrer exists
    IF v_referrer_id IS NOT NULL THEN
        -- SELF-REFERRAL DETECTION
        IF v_referrer_id = new.id THEN
            INSERT INTO public.fraud_flags (user_id, type, severity, details)
            VALUES (new.id, 'self_referral', 'high', jsonb_build_object('referrer_id', v_referrer_id));
        ELSE
            INSERT INTO public.referrals (referrer_id, referee_id)
            VALUES (v_referrer_id, new.id)
            ON CONFLICT (referee_id) DO NOTHING;
        END IF;
    END IF;

    -- MULTI-ACCOUNT DETECTION (Same Fingerprint)
    IF v_fingerprint IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.profiles WHERE fingerprint = v_fingerprint AND id != new.id
    ) THEN
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (new.id, 'multi_account', 'medium', jsonb_build_object('fingerprint', v_fingerprint));
    END IF;

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    RETURN new;
END;
$function$;

-- 4. Enhance claim_welcome_bonus to include social fraud detection
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
    v_duplicate_id uuid;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Validation patterns
    IF v_twitter_clean IS NOT NULL AND v_twitter_clean != '' AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    IF v_telegram_clean IS NOT NULL AND v_telegram_clean != '' AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- REQUIRED SOCIALS CHECK
    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram) to claim the bonus.');
    END IF;

    -- CROSS-ACCOUNT DUPLICATE SOCIAL DETECTION
    SELECT id INTO v_duplicate_id FROM public.profiles 
    WHERE id != _user_id 
    AND (
        (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
        (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean) OR
        (instagram_handle IS NOT NULL AND TRIM(LEADING '@' FROM instagram_handle) = v_instagram_clean) OR
        (facebook_handle IS NOT NULL AND facebook_handle = v_facebook_clean)
    )
    LIMIT 1;

    IF v_duplicate_id IS NOT NULL THEN
        -- Log fraud attempt
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (_user_id, 'social_duplicate', 'high', jsonb_build_object(
            'duplicate_user_id', v_duplicate_id,
            'twitter', v_twitter_clean,
            'telegram', v_telegram_clean
        ));
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

    -- Credit referrer
    IF v_profile.referred_by IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;
