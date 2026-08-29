CREATE TABLE IF NOT EXISTS public.points_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    reason TEXT NOT NULL,
    trigger_name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

GRANT SELECT ON public.points_audit_logs TO authenticated;
GRANT ALL ON public.points_audit_logs TO service_role;

ALTER TABLE public.points_audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all points audit logs"
    ON public.points_audit_logs
    FOR SELECT
    TO authenticated
    USING (public.has_role(auth.uid(), 'admin'));

-- Update handle_new_user to include audit logging
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
  SELECT (value->>0)::integer INTO v_welcome_bonus FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
  v_welcome_bonus := COALESCE(v_welcome_bonus, 50);

  SELECT id INTO v_referrer_id 
  FROM public.profiles 
  WHERE referral_code = (new.raw_user_meta_data->>'referral_code_used') 
  LIMIT 1;

  INSERT INTO public.profiles (
    id, email, full_name, username, avatar_url, points_balance, referred_by, has_claimed_welcome_bonus
  )
  VALUES (
    new.id, new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url',
    v_welcome_bonus, v_referrer_id, true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    avatar_url = EXCLUDED.avatar_url;

  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (new.id, v_welcome_bonus, 'welcome_bonus', 'Signup welcome bonus', 'completed');

  -- AUDIT LOG
  INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
  VALUES (new.id, v_welcome_bonus, 'Signup welcome bonus', 'handle_new_user');

  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO NOTHING;
    
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

-- Update handle_referral_reward_on_first_task to include audit logging
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
    IF (NEW.status = 'verified' AND (OLD.status IS NULL OR OLD.status != 'verified')) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.task_submissions 
            WHERE user_id = NEW.user_id 
            AND status = 'verified' 
            AND id != NEW.id
        ) THEN
            SELECT referred_by, username INTO v_referrer_id, v_referee_username 
            FROM public.profiles 
            WHERE id = NEW.user_id;

            IF v_referrer_id IS NOT NULL THEN
                SELECT (value->>0)::integer INTO v_referral_bonus 
                FROM public.app_settings 
                WHERE key = 'welcome_bonus_amount_referrer';
                
                v_referral_bonus := COALESCE(v_referral_bonus, 75);

                INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
                VALUES (
                    v_referrer_id,
                    v_referral_bonus,
                    'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed',
                    NEW.user_id
                );

                -- AUDIT LOG
                INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

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
