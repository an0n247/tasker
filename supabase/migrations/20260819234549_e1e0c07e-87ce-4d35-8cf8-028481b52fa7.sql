-- 1. Create referrals table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.referrals (
    referrer_id UUID REFERENCES auth.users(id),
    referee_id UUID PRIMARY KEY REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Grants for referrals table
GRANT SELECT, INSERT ON public.referrals TO authenticated;
GRANT ALL ON public.referrals TO service_role;

-- 3. RLS for referrals table
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'Users can view their own referrals') THEN
        CREATE POLICY "Users can view their own referrals" ON public.referrals 
        FOR SELECT TO authenticated 
        USING (auth.uid() = referrer_id OR auth.uid() = referee_id);
    END IF;
END $$;

-- 4. Update handle_new_user to correctly handle metadata and referrals
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

    -- Resolve referrer_id from metadata (checking both keys for robustness)
    v_referrer_id := (
        SELECT id FROM public.profiles 
        WHERE username = COALESCE(
            new.raw_user_meta_data->>'referral_code_used',
            new.raw_user_meta_data->>'referral_code'
        )
        LIMIT 1
    );

    -- Insert profile with hardened ON CONFLICT handling
    INSERT INTO public.profiles (
        id, 
        username, 
        full_name, 
        avatar_url,
        referral_code,
        referred_by
    )
    VALUES (
        new.id, 
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username,
        v_referrer_id
    )
    ON CONFLICT (id) DO UPDATE SET
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url,
        referred_by = EXCLUDED.referred_by;

    -- Also record in referrals table if referrer exists
    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.referrals (referrer_id, referee_id)
        VALUES (v_referrer_id, new.id)
        ON CONFLICT (referee_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;

-- 5. Update reward_referrer_on_signup with correct bonus values (75 referrer, 50 referee)
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75; -- Points awarded to the referrer
    v_referee_reward_points INTEGER := 50;  -- Points awarded to the referee (welcome bonus)
BEGIN
    -- Find the referrer (preferring the column in profiles or the referrals table)
    v_referrer_id := NEW.referred_by;
    
    IF v_referrer_id IS NULL THEN
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.id;
    END IF;

    -- If a referrer was found, award both parties
    IF v_referrer_id IS NOT NULL THEN
        -- Award Referrer (75 points)
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username
        );
        
        -- Award Referee (50 points welcome bonus)
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            NEW.id,
            v_referee_reward_points,
            'welcome_bonus',
            'Welcome bonus for joining via referral'
        );
        
        -- Notifications
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 6. Ensure the trigger is attached to profiles
DROP TRIGGER IF EXISTS on_profile_referral_reward ON public.profiles;
CREATE TRIGGER on_profile_referral_reward
    AFTER INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.reward_referrer_on_signup();

-- 7. Ensure handle_new_user trigger is attached to auth.users (if not already)
-- Note: This requires high privileges, but if it exists we just ensure it's correct.
-- In Lovable context, we assume on_auth_user_created already exists and calls handle_new_user.
