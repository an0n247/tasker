-- Upgrade referral validation with strict backend rules
CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _requesting_user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id uuid;
    v_referrer_username text;
    v_usage_count int;
    v_max_uses int := 100; -- Configurable limit
BEGIN
    -- 1. Self-referral check (if user is logged in/known)
    IF _requesting_user_id IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = _requesting_user_id AND referral_code = _code) THEN
            RETURN QUERY SELECT NULL::text, FALSE, 'You cannot refer yourself.'::text;
            RETURN;
        END IF;
    END IF;

    -- 2. Find referrer
    SELECT id, profiles.username INTO v_referrer_id, v_referrer_username
    FROM public.profiles
    WHERE referral_code = _code
    LIMIT 1;

    IF v_referrer_id IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    -- 3. Check usage limits (one-time use prevention / max capacity)
    IF _requesting_user_id IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = _requesting_user_id AND referred_by IS NOT NULL) THEN
            RETURN QUERY SELECT v_referrer_username, FALSE, 'You have already used a referral code.'::text;
            RETURN;
        END IF;
    END IF;

    -- 4. Capacity check
    SELECT count(*) INTO v_usage_count FROM public.profiles WHERE referred_by = v_referrer_id;
    IF v_usage_count >= v_max_uses THEN
        RETURN QUERY SELECT v_referrer_username, FALSE, 'This referral code has reached its maximum usage limit.'::text;
        RETURN;
    END IF;

    -- 5. Success
    RETURN QUERY SELECT v_referrer_username, TRUE, 'Valid referral code.'::text;
END;
$$;

-- Harden the signup trigger to enforce self-referral prevention and eligibility
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75;
    v_referee_reward_points INTEGER := 50;
    v_referral_exists BOOLEAN;
BEGIN
    -- 1. Identify Referrer
    v_referrer_id := NEW.referred_by;
    
    -- Fallback to referrals table if direct link is missing
    IF v_referrer_id IS NULL THEN
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.id;
    END IF;

    -- 2. Eligibility Guard: Prevent self-referral
    IF v_referrer_id = NEW.id THEN
        RAISE NOTICE 'Self-referral attempted and blocked for user %', NEW.id;
        RETURN NEW;
    END IF;

    -- 3. Eligibility Guard: Ensure referrer exists
    IF v_referrer_id IS NOT NULL THEN
        SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = v_referrer_id) INTO v_referral_exists;
        
        IF v_referral_exists THEN
            -- Award Referrer
            INSERT INTO public.points_transactions (user_id, amount, type, description)
            VALUES (v_referrer_id, v_referral_reward_points, 'referral', 'Referral bonus for ' || NEW.username);
            
            -- Award Referee
            INSERT INTO public.points_transactions (user_id, amount, type, description)
            VALUES (NEW.id, v_referee_reward_points, 'welcome_bonus', 'Welcome bonus for joining via referral');
            
            -- Notifications
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES 
                (v_referrer_id, 'Referral Reward!', 'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined.', 'reward'),
                (NEW.id, 'Welcome Bonus!', 'You earned ' || v_referee_reward_points || ' points for joining via referral.', 'reward');
        END IF;
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Prevent trigger failure from blocking account creation, except for explicit logic errors
    RETURN NEW;
END;
$$;
