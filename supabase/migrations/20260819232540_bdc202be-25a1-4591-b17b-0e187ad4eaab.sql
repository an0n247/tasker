CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    new_username text;
    base_username text;
    counter integer := 0;
BEGIN
    -- Extract username from metadata or email
    base_username := COALESCE(
        new.raw_user_meta_data->>'username',
        split_part(new.email, '@', 1)
    );
    
    -- Clean base_username (remove invalid characters for a clean username/referral code)
    base_username := regexp_replace(base_username, '[^a-zA-Z0-9_]', '', 'g');
    
    -- Ensure username is not empty after cleaning
    IF base_username = '' THEN
        base_username := 'user_' || substr(new.id::text, 1, 8);
    END IF;

    -- Ensure unique username
    new_username := base_username;
    WHILE EXISTS (SELECT 1 FROM public.profiles WHERE username = new_username) LOOP
        counter := counter + 1;
        new_username := base_username || counter::text;
    END LOOP;

    -- Insert profile with hardened ON CONFLICT handling
    INSERT INTO public.profiles (
        id, 
        username, 
        full_name, 
        avatar_url,
        referral_code
    )
    VALUES (
        new.id, 
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username
    )
    ON CONFLICT (id) DO UPDATE SET
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url;

    -- Handle referral if referral_code was provided during signup
    IF new.raw_user_meta_data->>'referral_code' IS NOT NULL THEN
        -- Using ON CONFLICT DO NOTHING to prevent errors if the link already exists
        INSERT INTO public.referrals (referrer_id, referee_id)
        SELECT id, new.id
        FROM public.profiles
        WHERE username = new.raw_user_meta_data->>'referral_code'
        ON CONFLICT (referee_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;