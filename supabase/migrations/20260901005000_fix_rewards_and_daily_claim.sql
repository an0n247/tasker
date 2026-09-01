-- Fix for Daily Streak Claim, Welcome Bonus, and Referral Reward System

-- 1. Redefine claim_daily_reward to check actual daily claim transactions
CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_streak_record record;
    v_points_to_add integer := 5;
    v_is_consecutive boolean := false;
    v_last_claim_date date;
    v_now timestamp with time zone := now();
    v_result_streak integer := 1;
BEGIN
    -- Authorization check
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: You can only claim rewards for your own account.');
    END IF;

    -- Transaction locking per user
    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text));

    -- Check if user already claimed today via points_transactions
    IF EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = _user_id
          AND (
            type = 'daily_claim' 
            OR description ILIKE '%Daily Check-in Streak Bonus%'
            OR description ILIKE '%Daily streak bonus%'
          )
          AND created_at::date = v_now::date
          AND status = 'completed'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
    END IF;

    -- Fetch existing streak record
    SELECT * INTO v_streak_record 
    FROM public.user_streaks 
    WHERE user_id = _user_id;

    -- Check last claim date from the latest completed daily claim transaction
    SELECT created_at::date INTO v_last_claim_date
    FROM public.points_transactions
    WHERE user_id = _user_id
      AND (
        type = 'daily_claim' 
        OR description ILIKE '%Daily Check-in Streak Bonus%'
        OR description ILIKE '%Daily streak bonus%'
      )
      AND status = 'completed'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_claim_date IS NOT NULL AND v_last_claim_date = (v_now::date - interval '1 day')::date THEN
        v_is_consecutive := true;
    END IF;

    -- Update or insert streak
    IF v_is_consecutive AND v_streak_record.current_streak IS NOT NULL AND v_streak_record.current_streak > 0 THEN
        v_result_streak := v_streak_record.current_streak + 1;
        UPDATE public.user_streaks
        SET 
            current_streak = v_result_streak,
            longest_streak = GREATEST(COALESCE(longest_streak, 0), v_result_streak),
            last_activity_at = v_now
        WHERE user_id = _user_id;
    ELSE
        v_result_streak := 1;
        INSERT INTO public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        VALUES (_user_id, 1, GREATEST(COALESCE(v_streak_record.longest_streak, 0), 1), v_now)
        ON CONFLICT (user_id) DO UPDATE 
        SET 
            current_streak = 1,
            longest_streak = GREATEST(public.user_streaks.longest_streak, 1),
            last_activity_at = v_now;
    END IF;

    -- Streak rewards schedule: Day 1: 5, Day 2: 5, Day 3: 10, Day 4: 10, Day 5: 15, Day 6: 15, Day 7+: 20
    IF v_result_streak = 1 THEN
        v_points_to_add := 5;
    ELSIF v_result_streak = 2 THEN
        v_points_to_add := 5;
    ELSIF v_result_streak = 3 THEN
        v_points_to_add := 10;
    ELSIF v_result_streak = 4 THEN
        v_points_to_add := 10;
    ELSIF v_result_streak = 5 THEN
        v_points_to_add := 15;
    ELSIF v_result_streak = 6 THEN
        v_points_to_add := 15;
    ELSE
        v_points_to_add := 20;
    END IF;

    -- Insert points transaction
    INSERT INTO public.points_transactions (user_id, amount, type, description, status, created_at)
    VALUES (_user_id, v_points_to_add, 'earn', format('Day %s Daily Check-in Streak Bonus', v_result_streak), 'completed', v_now);

    -- Sync points balance
    PERFORM public.sync_points_balance(_user_id);

    -- Create in-app notification
    INSERT INTO public.notifications (user_id, title, message, type, created_at)
    VALUES (_user_id, 'Daily Streak Bonus Claimed! 🔥', format('You claimed +%s PTS for maintaining your Day %s streak!', v_points_to_add, v_result_streak), 'points', v_now);

    RETURN json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', format('Day %s streak bonus claimed! +%s points', v_result_streak, v_points_to_add)
    );
END;
$function$;

-- 2. Redefine claim_welcome_bonus with robust JSON extraction and balance sync
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_bonus_enabled boolean := true;
    v_welcome_bonus integer := 50;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id FOR UPDATE;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    -- Check if already claimed
    IF v_profile.has_claimed_welcome_bonus OR EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = _user_id AND (type = 'bonus' OR type = 'welcome_bonus') AND status = 'completed'
    ) THEN
        UPDATE public.profiles SET has_claimed_welcome_bonus = true WHERE id = _user_id;
        RETURN json_build_object('success', false, 'alreadyClaimed', true, 'message', 'Welcome bonus already claimed');
    END IF;

    -- Fetch bonus amount from app_settings
    SELECT COALESCE(
      CASE
        WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
        WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
        ELSE NULL
      END,
      50
    )
    INTO v_welcome_bonus
    FROM public.app_settings
    WHERE key IN ('welcome_bonus_amount_referee', 'welcome_bonus')
    ORDER BY CASE WHEN key = 'welcome_bonus_amount_referee' THEN 0 ELSE 1 END
    LIMIT 1;

    v_welcome_bonus := COALESCE(v_welcome_bonus, 50);

    -- Mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        welcome_banner_dismissed = true
    WHERE id = _user_id;

    -- Insert completed transaction
    INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
    VALUES (_user_id, v_welcome_bonus, 'bonus', 'Welcome bonus', 'completed', _user_id)
    ON CONFLICT DO NOTHING;

    -- Sync user balance
    PERFORM public.sync_points_balance(_user_id);

    -- Create notification
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (_user_id, 'Welcome Bonus Claimed! 🎁', format('You claimed your +%s PTS welcome bonus!', v_welcome_bonus), 'points');

    RETURN json_build_object('success', true, 'points', v_welcome_bonus, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

-- 3. Redefine handle_new_user to ensure Welcome Bonus drops on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_welcome_bonus integer := 50;
  v_referrer_id uuid;
  v_supplied_referral text;
  v_username text;
  v_referral_code text;
BEGIN
  SELECT COALESCE(
    CASE
      WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
      WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
      ELSE NULL
    END,
    50
  )
  INTO v_welcome_bonus
  FROM public.app_settings
  WHERE key IN ('welcome_bonus_amount_referee', 'welcome_bonus')
  ORDER BY CASE WHEN key = 'welcome_bonus_amount_referee' THEN 0 ELSE 1 END
  LIMIT 1;

  v_welcome_bonus := COALESCE(v_welcome_bonus, 50);
  v_username := NULLIF(btrim(new.raw_user_meta_data->>'username'), '');
  v_supplied_referral := NULLIF(btrim(COALESCE(
    new.raw_user_meta_data->>'referral_code_used',
    new.raw_user_meta_data->>'referral_code',
    new.raw_user_meta_data->>'referred_by'
  )), '');

  IF v_supplied_referral IS NOT NULL THEN
    SELECT p.id
    INTO v_referrer_id
    FROM public.profiles p
    WHERE p.id <> new.id
      AND (
        lower(p.referral_code) = lower(v_supplied_referral)
        OR lower(p.username) = lower(v_supplied_referral)
      )
    ORDER BY CASE WHEN lower(p.referral_code) = lower(v_supplied_referral) THEN 0 ELSE 1 END
    LIMIT 1;
  END IF;

  v_referral_code := COALESCE(
    v_username,
    lower(split_part(COALESCE(new.email, new.id::text), '@', 1))
  );

  INSERT INTO public.profiles (
    id, email, points_balance, username, full_name, referral_code, referred_by, has_claimed_welcome_bonus
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_welcome_bonus,
    v_username,
    NULLIF(btrim(new.raw_user_meta_data->>'full_name'), ''),
    v_referral_code,
    v_referrer_id,
    TRUE
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = COALESCE(public.profiles.username, EXCLUDED.username),
      full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
      referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
      referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by),
      has_claimed_welcome_bonus = TRUE;

  -- Insert welcome bonus transaction
  INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
  VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus', 'completed', new.id)
  ON CONFLICT DO NOTHING;

  -- Initial streak setup (0 streak so user can claim day 1)
  INSERT INTO public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
  VALUES (new.id, 0, 0, NOW() - INTERVAL '2 days')
  ON CONFLICT (user_id) DO NOTHING;

  -- Record referral relationship
  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO UPDATE
    SET referrer_id = EXCLUDED.referrer_id;

    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    VALUES (
      v_referrer_id,
      'New Referral Joined!',
      'Someone signed up using your referral link. You will earn +75 PTS when they complete their first task!',
      'info',
      jsonb_build_object('referee_id', new.id)
    );
  END IF;

  -- Sync balance
  PERFORM public.sync_points_balance(new.id);

  RETURN new;
END;
$$;

-- 4. Referral Reward Trigger on First Task Completion
CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_referral_bonus integer := 75;
  v_referee_name text;
  v_transaction_id uuid;
  v_is_new_verified boolean;
BEGIN
  v_is_new_verified := (TG_OP = 'INSERT' AND NEW.status = 'verified')
    OR (TG_OP = 'UPDATE' AND NEW.status = 'verified' AND (OLD.status IS NULL OR OLD.status <> 'verified'));

  IF v_is_new_verified THEN
    SELECT r.referrer_id INTO v_referrer_id 
    FROM public.referrals r 
    WHERE r.referee_id = NEW.user_id;

    IF v_referrer_id IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

      -- Reward only once per referee
      IF NOT EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = v_referrer_id AND type = 'referral' AND source_id = NEW.user_id
      ) THEN
        SELECT COALESCE(
          CASE
            WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
            WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
            ELSE NULL
          END, 
          75
        )
        INTO v_referral_bonus
        FROM public.app_settings
        WHERE key IN ('welcome_bonus_amount_referrer', 'referral_bonus')
        ORDER BY CASE WHEN key = 'welcome_bonus_amount_referrer' THEN 0 ELSE 1 END
        LIMIT 1;

        v_referral_bonus := COALESCE(v_referral_bonus, 75);

        SELECT COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your referral')
        INTO v_referee_name FROM public.profiles p WHERE p.id = NEW.user_id;

        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
          v_referrer_id, 
          v_referral_bonus, 
          'referral',
          'Referral bonus: ' || COALESCE(v_referee_name, 'your referral') || ' completed their first task',
          'completed', 
          NEW.user_id
        )
        RETURNING id INTO v_transaction_id;

        IF v_transaction_id IS NOT NULL THEN
          -- Sync referrer balance immediately
          PERFORM public.sync_points_balance(v_referrer_id);

          INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
          VALUES (
            v_referrer_id, 
            v_referral_bonus,
            'Referral bonus for ' || COALESCE(v_referee_name, 'referee') || '''s first task',
            'handle_referral_reward_on_first_task'
          );

          INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
          VALUES (
            v_referrer_id,
            'Referral Reward Earned! 🎉',
            'You earned +' || v_referral_bonus || ' PTS because ' || COALESCE(v_referee_name, 'your referral') || ' completed their first task!',
            'reward',
            v_transaction_id,
            jsonb_build_object('referee_id', NEW.user_id, 'points', v_referral_bonus)
          );
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 5. Backfill Welcome Bonus for any registered users who missed it
DO $$
DECLARE
  u record;
BEGIN
  FOR u IN 
    SELECT p.id 
    FROM public.profiles p
    WHERE NOT EXISTS (
      SELECT 1 FROM public.points_transactions pt
      WHERE pt.user_id = p.id AND pt.type IN ('bonus', 'welcome_bonus') AND pt.status = 'completed'
    )
  LOOP
    INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
    VALUES (u.id, 50, 'bonus', 'Welcome bonus', 'completed', u.id)
    ON CONFLICT DO NOTHING;

    UPDATE public.profiles SET has_claimed_welcome_bonus = true WHERE id = u.id;
    PERFORM public.sync_points_balance(u.id);
  END LOOP;
END $$;

-- 6. Backfill missing referral links if users registered with referral code
DO $$
DECLARE
  p record;
BEGIN
  FOR p IN 
    SELECT id, referred_by 
    FROM public.profiles 
    WHERE referred_by IS NOT NULL 
      AND NOT EXISTS (SELECT 1 FROM public.referrals WHERE referee_id = profiles.id)
  LOOP
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (p.referred_by, p.id)
    ON CONFLICT (referee_id) DO NOTHING;
  END LOOP;
END $$;

-- 7. Ensure permissions
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO authenticated, service_role;
