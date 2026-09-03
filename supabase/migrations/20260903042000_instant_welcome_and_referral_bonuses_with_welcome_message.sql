-- ==============================================================================
-- Migration: Instant Welcome & Referral Bonuses + Automated Welcome Inbox Message
-- ==============================================================================

-- 1. Helper function: Get system admin ID for sending official messages
CREATE OR REPLACE FUNCTION public.get_system_admin_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT u.id FROM auth.users u WHERE LOWER(u.email) = 'olalekanhq@yahoo.com' LIMIT 1),
    (SELECT user_id FROM public.user_roles WHERE role = 'admin' LIMIT 1),
    (SELECT id FROM public.profiles LIMIT 1)
  );
$$;


-- 2. Definitive handle_new_user function
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

  -- 2. Fetch bonus amounts from app_settings
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

  -- 4. Generate unique referral code for new user
  v_referral_code := COALESCE(
    v_username,
    lower(split_part(COALESCE(new.email, new.id::text), '@', 1))
  );

  -- 5. Create / Update Profile
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
    TRUE,
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

  -- 8. Credit NEW USER with Welcome Bonus (+50 PTS)
  IF NOT EXISTS (
    SELECT 1 FROM public.points_transactions 
    WHERE user_id = new.id AND (type = 'bonus' OR type = 'welcome_bonus')
  ) THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
    VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus for joining Noble Gain', 'completed', new.id::text, v_now);
  END IF;

  -- Welcome Notification
  INSERT INTO public.notifications (user_id, title, message, type, created_at)
  VALUES (
    new.id,
    'Welcome to Noble Gain! 🎁',
    format('Your +%s PTS welcome bonus has been credited to your balance! Start completing tasks to earn more.', v_welcome_bonus),
    'points',
    v_now
  );

  -- 9. Send Warm Welcome Message directly to the new user's inbox
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
      '• Invite Friends: Share your unique referral code (@' || COALESCE(v_referral_code, 'code') || ') to earn +' || v_referral_bonus || ' PTS per friend' || E'\n\n' ||
      'If you have any questions, encounter any issues, or need support, simply reply directly to this message. We are always here to help!' || E'\n\n' ||
      'Warm regards,' || E'\n' ||
      'The Noble Gain Team',
      FALSE,
      TRUE,
      v_now,
      v_now
    );
  END IF;

  -- 10. Process REFERRAL BONUS (+75 PTS) for Referrer immediately
  IF v_referrer_id IS NOT NULL THEN
    -- Record referral record
    INSERT INTO public.referrals (referrer_id, referee_id, created_at)
    VALUES (v_referrer_id, new.id, v_now)
    ON CONFLICT (referee_id) DO UPDATE SET referrer_id = EXCLUDED.referrer_id;

    -- Credit referrer with bonus if not already awarded for this referee
    IF NOT EXISTS (
      SELECT 1 FROM public.points_transactions 
      WHERE user_id = v_referrer_id AND type = 'referral' AND source_id = new.id::text
    ) THEN
      INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
      VALUES (
        v_referrer_id,
        v_referral_bonus,
        'referral',
        'Referral bonus for inviting @' || COALESCE(v_username, 'a new member'),
        'completed',
        new.id::text,
        v_now
      );

      -- Referrer notification
      INSERT INTO public.notifications (user_id, title, message, type, metadata, created_at)
      VALUES (
        v_referrer_id,
        'New Referral Joined! 🎉',
        format('Someone joined using your invite link (@%s)! +%s PTS has been credited to your balance.', COALESCE(v_username, 'new member'), v_referral_bonus),
        'referral',
        jsonb_build_object('referee_id', new.id, 'points', v_referral_bonus),
        v_now
      );

      -- Resynchronize referrer balance
      UPDATE public.profiles
      SET points_balance = GREATEST(0, COALESCE((
          SELECT SUM(amount) FROM public.points_transactions WHERE user_id = v_referrer_id AND (status IS NULL OR status = 'completed')
      ), 0))
      WHERE id = v_referrer_id;
    END IF;
  END IF;

  -- 11. Resynchronize new user balance
  UPDATE public.profiles
  SET points_balance = GREATEST(0, COALESCE((
      SELECT SUM(amount) FROM public.points_transactions WHERE user_id = new.id AND (status IS NULL OR status = 'completed')
  ), 0))
  WHERE id = new.id;

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user error for user %: %', new.id, SQLERRM;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role, anon, authenticated;


-- ==============================================================================
-- 3. RETROACTIVE BACKFILL FOR EXISTING USERS
-- Ensure all existing users have their welcome bonus and referrals credited
-- ==============================================================================

-- A. Backfill Welcome Bonus (+50 PTS) for any profile missing it
INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
SELECT p.id, 50, 'bonus', 'Welcome bonus for joining Noble Gain', 'completed', p.id::text, p.created_at
FROM public.profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM public.points_transactions pt
  WHERE pt.user_id = p.id AND (pt.type = 'bonus' OR pt.type = 'welcome_bonus')
);

-- Mark all profiles as has_claimed_welcome_bonus = true
UPDATE public.profiles
SET has_claimed_welcome_bonus = true,
    welcome_banner_dismissed = true;

-- B. Backfill Referral Bonus (+75 PTS) for referrers who haven't received it
INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id, created_at)
SELECT r.referrer_id, 75, 'referral', 'Referral bonus for inviting @' || COALESCE(p.username, 'member'), 'completed', r.referee_id::text, r.created_at
FROM public.referrals r
JOIN public.profiles p ON p.id = r.referee_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.points_transactions pt
  WHERE pt.user_id = r.referrer_id AND pt.type = 'referral' AND pt.source_id = r.referee_id::text
);

-- C. Send warm welcome messages to all existing users who don't have one
DO $$
DECLARE
  v_admin_id uuid := public.get_system_admin_id();
  v_user record;
BEGIN
  IF v_admin_id IS NOT NULL THEN
    FOR v_user IN 
      SELECT p.id, p.username, p.full_name, p.referral_code
      FROM public.profiles p
      WHERE p.id <> v_admin_id
        AND NOT EXISTS (
          SELECT 1 FROM public.messages m
          WHERE m.recipient_id = p.id AND m.subject LIKE 'Welcome to Noble Gain%'
        )
    LOOP
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
        v_admin_id,
        v_user.id,
        'Welcome to Noble Gain! 🌟 Start Earning Today',
        'Hello ' || COALESCE(v_user.full_name, v_user.username, 'Member') || '! 👋' || E'\n\n' ||
        'Welcome to Noble Gain! We are thrilled to have you in our earning community.' || E'\n\n' ||
        'Your +50 PTS welcome bonus has already been added to your vault balance.' || E'\n\n' ||
        'Here is how you can get started earning rewards right away:' || E'\n' ||
        '• Complete Daily Tasks: Read, like & comment on partner articles' || E'\n' ||
        '• Daily Check-in: Build your consecutive streak to unlock multiplier rewards' || E'\n' ||
        '• Invite Friends: Share your unique referral code (@' || COALESCE(v_user.referral_code, 'code') || ') to earn +75 PTS per friend' || E'\n\n' ||
        'If you have any questions, encounter any issues, or need support, simply reply directly to this message. We are always here to help!' || E'\n\n' ||
        'Warm regards,' || E'\n' ||
        'The Noble Gain Team',
        FALSE,
        TRUE,
        NOW(),
        NOW()
      );
    END LOOP;
  END IF;
END $$;

-- D. Final resynchronization of all user point balances from completed transactions
UPDATE public.profiles p
SET points_balance = GREATEST(0, COALESCE((
    SELECT SUM(pt.amount) 
    FROM public.points_transactions pt 
    WHERE pt.user_id = p.id 
      AND (pt.status IS NULL OR pt.status = 'completed')
), 0));
