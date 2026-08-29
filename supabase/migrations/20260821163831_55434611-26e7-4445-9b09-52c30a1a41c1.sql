DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_welcome_bonus INTEGER;
BEGIN
  -- 1. Read welcome bonus amount from settings
  SELECT (value->>0)::integer INTO v_welcome_bonus FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
  v_welcome_bonus := COALESCE(v_welcome_bonus, 50);

  -- 2. Determine referrer
  SELECT id INTO v_referrer_id 
  FROM public.profiles 
  WHERE referral_code = (new.raw_user_meta_data->>'referral_code_used') 
  LIMIT 1;

  -- 3. Create profile
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    username,
    avatar_url,
    points_balance,
    referred_by,
    has_claimed_welcome_bonus
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url',
    v_welcome_bonus,
    v_referrer_id,
    true -- Mark as claimed because we are giving it automatically
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    avatar_url = EXCLUDED.avatar_url;

  -- 4. Record welcome bonus transaction
  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (new.id, v_welcome_bonus, 'welcome_bonus', 'Signup welcome bonus', 'completed');

  -- 5. Ensure record exists in referrals table if referred
  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO NOTHING;
    
    -- Notify the referrer (but don't give points yet)
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
      v_referrer_id,
      'New Referral!',
      'Someone just signed up using your link! You will earn a bonus once they complete their first task.',
      'info'
    );
  END IF;
  
  RETURN new;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;

-- 6. Update Task Reward logic to handle referral bonus
CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_bonus INTEGER;
    v_referee_username TEXT;
BEGIN
    -- Only trigger when a task is verified
    IF (NEW.status = 'verified' AND (OLD.status IS NULL OR OLD.status != 'verified')) THEN
        
        -- Check if this is the user's FIRST verified task
        IF NOT EXISTS (
            SELECT 1 FROM public.task_submissions 
            WHERE user_id = NEW.user_id 
            AND status = 'verified' 
            AND id != NEW.id
        ) THEN
            -- Get referrer
            SELECT referred_by, username INTO v_referrer_id, v_referee_username 
            FROM public.profiles 
            WHERE id = NEW.user_id;

            IF v_referrer_id IS NOT NULL THEN
                -- Get referral bonus amount
                SELECT (value->>0)::integer INTO v_referral_bonus 
                FROM public.app_settings 
                WHERE key = 'welcome_bonus_amount_referrer';
                
                v_referral_bonus := COALESCE(v_referral_bonus, 75);

                -- Award points to referrer
                INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
                VALUES (
                    v_referrer_id,
                    v_referral_bonus,
                    'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed',
                    NEW.user_id
                );

                -- Notify referrer
                INSERT INTO public.notifications (user_id, title, message, type)
                VALUES (
                    v_referrer_id,
                    'Referral Reward Earned!',
                    'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                    'reward'
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_handle_referral_reward_on_first_task ON public.task_submissions;
CREATE TRIGGER tr_handle_referral_reward_on_first_task
  AFTER UPDATE ON public.task_submissions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_referral_reward_on_first_task();

GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO service_role;

-- 7. Clean up old triggers that might conflict
DROP TRIGGER IF EXISTS on_profile_referral_reward ON public.profiles;
DROP TRIGGER IF EXISTS on_profile_update_check_referral ON public.profiles;
DROP TRIGGER IF EXISTS on_profile_completion ON public.profiles;
