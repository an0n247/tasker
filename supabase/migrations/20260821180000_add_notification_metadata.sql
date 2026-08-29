-- Add metadata column to notifications if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'metadata') THEN
        ALTER TABLE public.notifications ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- Update handle_new_user to include referee_id in metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_welcome_bonus integer;
  v_referrer_id uuid;
BEGIN
  -- Get welcome bonus from settings
  SELECT (value->>'amount')::integer INTO v_welcome_bonus
  FROM public.app_settings
  WHERE key = 'welcome_bonus';

  IF v_welcome_bonus IS NULL THEN
    v_welcome_bonus := 50; -- Default
  END IF;

  -- Create profile
  INSERT INTO public.profiles (id, email, points_balance, username, full_name)
  VALUES (
    new.id,
    new.email,
    v_welcome_bonus,
    new.raw_user_meta_data->>'username',
    new.raw_user_meta_data->>'full_name'
  );

  -- Credit points
  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus', 'completed');

  -- Handle referral if exists
  v_referrer_id := (new.raw_user_meta_data->>'referred_by')::uuid;
  
  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO NOTHING;
    
    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    VALUES (
      v_referrer_id,
      'New Referral!',
      'Someone just signed up using your link! You will earn a bonus once they complete their first task.',
      'info',
      jsonb_build_object('referee_id', new.id)
    );
  END IF;
  
  RETURN new;
END;
$$;

-- Update handle_referral_reward_on_first_task to include referee_id in metadata
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
    v_transaction_id UUID;
BEGIN
    -- Only trigger if task is approved
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status != 'approved') THEN
        -- Check if user was referred
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.user_id;

        IF v_referrer_id IS NOT NULL THEN
            -- Check if referral bonus already paid
            IF NOT EXISTS (
                SELECT 1 FROM public.points_transactions 
                WHERE user_id = v_referrer_id 
                AND type = 'referral' 
                AND source_id = NEW.user_id::text
            ) THEN
                -- Get bonus amount
                SELECT (value->>'amount')::integer INTO v_referral_bonus
                FROM public.app_settings
                WHERE key = 'referral_bonus';
                
                IF v_referral_bonus IS NULL THEN
                    v_referral_bonus := 75;
                END IF;

                SELECT username INTO v_referee_username
                FROM public.profiles
                WHERE id = NEW.user_id;

                -- CREATE TRANSACTION
                INSERT INTO public.points_transactions (
                    user_id,
                    amount,
                    type,
                    description,
                    status,
                    source_id
                ) VALUES (
                    v_referrer_id,
                    v_referral_bonus,
                    'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed',
                    NEW.user_id
                ) RETURNING id INTO v_transaction_id;

                -- AUDIT LOG
                INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

                INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
                VALUES (
                    v_referrer_id,
                    'Referral Reward Earned!',
                    'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                    'reward',
                    v_transaction_id,
                    jsonb_build_object('referee_id', NEW.user_id)
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;
