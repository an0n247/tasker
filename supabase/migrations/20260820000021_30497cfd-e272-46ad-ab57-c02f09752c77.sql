-- 1. Harden handle_new_user trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    new_username text;
    base_username text;
    counter integer := 0;
    v_referrer_id uuid;
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
        referred_by
    )
    VALUES (
        new.id, 
        new.email,
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username,
        v_referrer_id
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url,
        referred_by = EXCLUDED.referred_by;

    -- Record in referrals table if referrer exists
    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.referrals (referrer_id, referee_id)
        VALUES (v_referrer_id, new.id)
        ON CONFLICT (referee_id) DO NOTHING;
    END IF;

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    RETURN new;
END;
$$;

-- 2. Harden reward_referrer_on_signup trigger function
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75; -- Points awarded to the referrer
    v_referee_reward_points INTEGER := 50;  -- Points awarded to the referee
BEGIN
    -- Find the referrer
    v_referrer_id := NEW.referred_by;
    
    IF v_referrer_id IS NULL THEN
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.id;
    END IF;

    -- If a referrer was found, award both parties
    IF v_referrer_id IS NOT NULL THEN
        -- Award Referrer
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username
        );
        
        -- Award Referee
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            NEW.id,
            v_referee_reward_points,
            'welcome_bonus',
            'Welcome bonus for joining via referral'
        );
        
        -- Notifications (Safe check)
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                v_referrer_id,
                'Referral Reward!',
                'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined using your code.',
                'reward'
            );
            
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                NEW.id,
                'Welcome Bonus!',
                'You earned ' || v_referee_reward_points || ' points as a welcome bonus for joining via referral.',
                'reward'
            );
        END IF;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;

-- 3. Grants
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role, postgres;
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT INSERT ON public.points_transactions TO authenticated;
GRANT INSERT ON public.referrals TO authenticated;
