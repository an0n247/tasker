-- ==============================================================================
-- Migration: Referral Bonus on First Task Completion + Welcome Bonus on Signup
-- ==============================================================================

-- 1. Redefine handle_new_user (Welcome Bonus on signup, Referral Bonus pending first task)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_welcome_bonus integer := 50;
  v_referral_bonus integer := 75;
  v_referrer_id uuid;
  v_supplied_referral text;
  v_username text;
  v_full_name text;
  v_referral_code text;
  v_admin_sender_id uuid;
  v_now timestamptz := NOW();
BEGIN
  -- 1. Extract metadata
  v_username := NULLIF(btrim(new.raw_user_meta_data->>'username'), '');
  v_full_name := NULLIF(btrim(new.raw_user_meta_data->>'full_name'), '');
  v_supplied_referral := NULLIF(btrim(COALESCE(
    new.raw_user_meta_data->>'referral_code_used',
    new.raw_user_meta_data->>'referral_code',
    new.raw_user_meta_data->>'referred_by'
  )), '');

  -- 2. Fetch bonus amount from app_settings
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

  -- 3. Match referrer by code or username
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

  -- 4. Generate referral code
  v_referral_code := COALESCE(
    v_username,
    lower(split_part(COALESCE(new.email, new.id::text), '@', 1))
  );

  -- 5. Create Profile with Welcome Bonus
  INSERT INTO public.profiles (
    id, email, points_balance, username, full_name, referral_code, referral_code_used, referred_by, has_claimed_welcome_bonus, welcome_banner_dismissed, created_at, updated_at
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_welcome_bonus,
    v_username,
    v_full_name,
    v_referral_code,
    v_supplied_referral,
    v_referrer_id,
    TRUE,
    FALSE,
    v_now,
    v_now
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = COALESCE(public.profiles.username, EXCLUDED.username),
      full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
      referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
      referral_code_used = COALESCE(public.profiles.referral_code_used, EXCLUDED.referral_code_used),
      referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by),
      has_claimed_welcome_bonus = TRUE,
      updated_at = v_now;

  -- 6. Assign default 'user' role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (new.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  -- 7. Initialize User Streak
  INSERT INTO public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
  VALUES (new.id, 0, 0, v_now - INTERVAL '2 days')
  ON CONFLICT (user_id) DO NOTHING;

  -- 8. Credit NEW USER with +50 PTS Welcome Bonus
  IF NOT EXISTS (
    SELECT 1 FROM public.points_transactions 
    WHERE user_id = new.id AND (type = 'bonus' OR type = 'welcome_bonus')
  ) THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
    VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus for joining Noble Gain', 'completed', new.id::text, v_now);
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type, created_at)
  VALUES (
    new.id,
    'Welcome to Noble Gain! 🎁',
    format('Your +%s PTS welcome bonus has been credited to your balance!', v_welcome_bonus),
    'points',
    v_now
  );

  -- 9. Send Warm Welcome Message to New User's Inbox
  v_admin_sender_id := public.get_system_admin_id();
  IF v_admin_sender_id IS NOT NULL AND v_admin_sender_id <> new.id THEN
    INSERT INTO public.messages (
      sender_id,
      recipient_id,
      subject,
      body,
      is_broadcast,
      allow_replies,
      created_at,
      updated_at
    )
    VALUES (
      v_admin_sender_id,
      new.id,
      'Welcome to Noble Gain! 🌟 Start Earning Today',
      'Hello ' || COALESCE(v_full_name, v_username, 'Member') || '! 👋' || E'\n\n' ||
      'Welcome to Noble Gain! We are thrilled to have you in our earning community.' || E'\n\n' ||
      'Your +' || v_welcome_bonus || ' PTS welcome bonus has already been added to your vault balance.' || E'\n\n' ||
      'Here is how you can get started earning rewards right away:' || E'\n' ||
      '• Complete Daily Tasks: Read, like & comment on partner articles' || E'\n' ||
      '• Daily Check-in: Build your consecutive streak to unlock multiplier rewards' || E'\n' ||
      '• Invite Friends: Share your unique referral code (@' || COALESCE(v_referral_code, 'code') || ') to earn +75 PTS when they complete their first task' || E'\n\n' ||
      'If you have any questions, encounter any issues, or need support, simply reply directly to this message. We are always here to help!' || E'\n\n' ||
      'Warm regards,' || E'\n' ||
      'The Noble Gain Team',
      FALSE,
      TRUE,
      v_now,
      v_now
    );
  END IF;

  -- 10. Record Referral Link & Notify Referrer (Reward will be given when referee completes first task)
  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id, created_at)
    VALUES (v_referrer_id, new.id, v_now)
    ON CONFLICT (referee_id) DO UPDATE SET referrer_id = EXCLUDED.referrer_id;

    INSERT INTO public.notifications (user_id, title, message, type, metadata, created_at)
    VALUES (
      v_referrer_id,
      'New Referral Joined! 👥',
      format('Someone joined using your invite link (@%s)! You will earn +75 PTS as soon as they complete their first task.', COALESCE(v_username, 'new member')),
      'referral',
      jsonb_build_object('referee_id', new.id),
      v_now
    );
  END IF;

  -- 11. Resynchronize new user balance
  UPDATE public.profiles
  SET points_balance = GREATEST(0, COALESCE((
      SELECT SUM(amount) FROM public.points_transactions WHERE user_id = new.id AND (status IS NULL OR status = 'completed')
  ), 0))
  WHERE id = new.id;

  RETURN new;
END;
$$;


-- ==============================================================================
-- 2. Trigger Function: Credit Referrer ONLY when Referee completes their FIRST task
-- ==============================================================================
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
  v_referee_id uuid;
  v_is_eligible_completion boolean;
  v_transaction_id uuid;
BEGIN
  -- Determine referee_id and whether task is completed / verified
  IF TG_TABLE_NAME = 'task_submissions' THEN
    v_referee_id := NEW.user_id;
    v_is_eligible_completion := (NEW.status IN ('verified', 'completed', 'approved'))
      AND (TG_OP = 'INSERT' OR OLD.status NOT IN ('verified', 'completed', 'approved'));
  ELSIF TG_TABLE_NAME = 'points_transactions' THEN
    v_referee_id := NEW.user_id;
    v_is_eligible_completion := (NEW.type IN ('earn', 'task')) AND NEW.amount > 0 AND (NEW.status IS NULL OR NEW.status = 'completed');
  END IF;

  IF v_is_eligible_completion AND v_referee_id IS NOT NULL THEN
    -- Check if this user was referred by someone
    SELECT r.referrer_id INTO v_referrer_id
    FROM public.referrals r
    WHERE r.referee_id = v_referee_id;

    IF v_referrer_id IS NOT NULL THEN
      -- Use advisory lock to prevent duplicate referral rewards
      PERFORM pg_advisory_xact_lock(hashtext('ref_reward_' || v_referrer_id::text || '_' || v_referee_id::text));

      -- Check if referral bonus was already granted for this referee
      IF NOT EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = v_referrer_id 
          AND type = 'referral' 
          AND source_id = v_referee_id::text
      ) THEN
        -- Get configured referral bonus amount
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
        INTO v_referee_name FROM public.profiles p WHERE p.id = v_referee_id;

        -- Insert referral bonus for the referrer
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
        VALUES (
          v_referrer_id,
          v_referral_bonus,
          'referral',
          'Referral bonus: @' || COALESCE(v_referee_name, 'member') || ' completed their first task',
          'completed',
          v_referee_id::text,
          NOW()
        )
        RETURNING id INTO v_transaction_id;

        -- Notify the referrer
        INSERT INTO public.notifications (user_id, title, message, type, metadata, created_at)
        VALUES (
          v_referrer_id,
          'Referral Completed First Task! 🎉',
          format('Great news! @%s just completed their first task. You earned +%s PTS referral bonus!', COALESCE(v_referee_name, 'your referral'), v_referral_bonus),
          'referral',
          jsonb_build_object('referee_id', v_referee_id, 'points', v_referral_bonus),
          NOW()
        );

        -- Resynchronize referrer balance
        UPDATE public.profiles
        SET points_balance = GREATEST(0, COALESCE((
            SELECT SUM(amount) FROM public.points_transactions WHERE user_id = v_referrer_id AND (status IS NULL OR status = 'completed')
        ), 0))
        WHERE id = v_referrer_id;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Triggers for First Task Completion
DROP TRIGGER IF EXISTS trg_referral_reward_on_task_submission ON public.task_submissions;
CREATE TRIGGER trg_referral_reward_on_task_submission
  AFTER INSERT OR UPDATE ON public.task_submissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_referral_reward_on_first_task();

DROP TRIGGER IF EXISTS trg_referral_reward_on_points_earn ON public.points_transactions;
CREATE TRIGGER trg_referral_reward_on_points_earn
  AFTER INSERT ON public.points_transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_referral_reward_on_first_task();
