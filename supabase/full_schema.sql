-- ==============================================================================
-- NOBLE GAIN — Master Canonical Database Schema
-- Resets the public schema and builds the full production database in one clean pass.
-- ==============================================================================

-- 1. Reset Public Schema
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA public TO authenticated;
GRANT ALL ON SCHEMA public TO service_role;

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- 2. Custom Types / Enums
CREATE TYPE public.app_role AS ENUM ('admin', 'user', 'tasker', 'moderator', 'task_manager');

-- 3. Core Tables

-- Profiles table
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    points_balance INTEGER DEFAULT 0 NOT NULL,
    referral_code TEXT UNIQUE,
    referral_code_used TEXT,
    referred_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    username TEXT UNIQUE,
    phone_number TEXT,
    twitter_handle TEXT,
    telegram_handle TEXT,
    facebook_handle TEXT,
    instagram_handle TEXT,
    fingerprint TEXT,
    last_ip TEXT,
    has_claimed_welcome_bonus BOOLEAN DEFAULT FALSE,
    welcome_banner_dismissed BOOLEAN DEFAULT FALSE,
    email_notifications BOOLEAN DEFAULT TRUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    referral_clicks INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- User Roles table
CREATE TABLE public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

-- App Settings table
CREATE TABLE public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks table
CREATE TABLE public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    points INTEGER NOT NULL,
    category TEXT DEFAULT 'general',
    icon_name TEXT,
    link_url TEXT,
    vast_tag_url TEXT,
    video_ad_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    is_featured BOOLEAN DEFAULT FALSE,
    is_repeatable BOOLEAN DEFAULT FALSE,
    verification_required BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Task Submissions table
CREATE TABLE public.task_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' NOT NULL,
    admin_note TEXT,
    proof_image_url TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (user_id, task_id)
);

-- Points Transactions table
CREATE TABLE public.points_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    type TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'completed',
    source_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Points Audit Logs table
CREATE TABLE public.points_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    reason TEXT NOT NULL,
    trigger_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Admin Audit Logs table
CREATE TABLE public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    target_table TEXT NOT NULL,
    target_id TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Rewards table
CREATE TABLE public.rewards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    cost_points INTEGER NOT NULL,
    category TEXT,
    image_url TEXT,
    stock_count INTEGER,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Redemptions table
CREATE TABLE public.redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reward_id UUID NOT NULL REFERENCES public.rewards(id) ON DELETE RESTRICT,
    status TEXT DEFAULT 'pending' NOT NULL,
    fraud_score NUMERIC,
    fraud_details JSONB,
    is_flagged BOOLEAN DEFAULT FALSE,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    transaction_id UUID REFERENCES public.points_transactions(id) ON DELETE SET NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Fraud Flags table
CREATE TABLE public.fraud_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    severity TEXT DEFAULT 'low',
    status TEXT DEFAULT 'open',
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Role Permissions table
CREATE TABLE public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role public.app_role NOT NULL,
    tab_name TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (role, tab_name)
);

-- Signup OTPs table
CREATE TABLE public.signup_otps (
    email TEXT PRIMARY KEY,
    code_hash TEXT NOT NULL,
    attempts INTEGER DEFAULT 0 NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- User Streaks table
CREATE TABLE public.user_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    longest_streak INTEGER DEFAULT 0 NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Referrals table
CREATE TABLE public.referrals (
    referee_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    referrer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Analytics Events table
CREATE TABLE public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    event_name TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Video Watch Sessions table
CREATE TABLE public.video_watch_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    min_watch_seconds INTEGER DEFAULT 15 NOT NULL,
    consumed BOOLEAN DEFAULT FALSE NOT NULL,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour') NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Video Ad Progress table
CREATE TABLE public.video_ad_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    watch_count INTEGER DEFAULT 0 NOT NULL,
    last_watch_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    UNIQUE (user_id, task_id)
);

-- 4. Views

-- Leaderboard view
CREATE OR REPLACE VIEW public.leaderboard WITH (security_invoker = true) AS
SELECT 
    p.id,
    p.full_name,
    p.username,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

-- User Ranks view
CREATE OR REPLACE VIEW public.user_ranks WITH (security_invoker = true) AS
SELECT 
    p.id as user_id,
    p.username,
    COALESCE(r.referral_count, 0) as referral_count,
    CASE 
        WHEN COALESCE(r.referral_count, 0) >= 50 THEN 'Legend'
        WHEN COALESCE(r.referral_count, 0) >= 20 THEN 'Pro'
        WHEN COALESCE(r.referral_count, 0) >= 10 THEN 'Super Referrer'
        WHEN COALESCE(r.referral_count, 0) >= 5 THEN 'Elite'
        ELSE 'Novice'
    END as rank_name,
    CASE 
        WHEN COALESCE(r.referral_count, 0) >= 50 THEN 5
        WHEN COALESCE(r.referral_count, 0) >= 20 THEN 4
        WHEN COALESCE(r.referral_count, 0) >= 10 THEN 3
        WHEN COALESCE(r.referral_count, 0) >= 5 THEN 2
        ELSE 1
    END as rank_level
FROM public.profiles p
LEFT JOIN (
    SELECT referrer_id, COUNT(*) as referral_count
    FROM public.referrals
    GROUP BY referrer_id
) r ON p.id = r.referrer_id;

-- Detailed Referrals view
CREATE OR REPLACE VIEW public.my_referrals_detailed WITH (security_invoker = true) AS
SELECT 
    r.referrer_id,
    p.id as referee_id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.created_at as joined_at,
    CASE WHEN p.has_claimed_welcome_bonus THEN 'Active' ELSE 'Pending Profile' END as status
FROM public.referrals r
JOIN public.profiles p ON r.referee_id = p.id;

-- Referrals with Profiles view
CREATE OR REPLACE VIEW public.referrals_with_profiles WITH (security_invoker = true) AS
SELECT 
    r.referrer_id,
    r.referee_id,
    r.created_at,
    referrer.username AS referrer_username,
    referrer.full_name AS referrer_full_name,
    referrer.avatar_url AS referrer_avatar_url,
    referrer.email AS referrer_email,
    referrer.points_balance AS referrer_points_balance,
    referrer.referral_code AS referrer_referral_code,
    referee.username AS referee_username,
    referee.full_name AS referee_full_name,
    referee.email AS referee_email,
    referee.created_at AS referee_created_at,
    referee.twitter_handle AS referee_twitter_handle,
    referee.telegram_handle AS referee_telegram_handle,
    referee.has_claimed_welcome_bonus AS referee_has_claimed_welcome_bonus
FROM public.referrals r
JOIN public.profiles referrer ON r.referrer_id = referrer.id
JOIN public.profiles referee ON r.referee_id = referee.id;

-- Global Referral Stats view
CREATE OR REPLACE VIEW public.global_referral_stats WITH (security_invoker = true) AS
SELECT 
    COUNT(DISTINCT referrer_id) as total_referrers,
    COUNT(*) as total_referrals,
    COUNT(CASE WHEN p.has_claimed_welcome_bonus THEN 1 END) as completed_referrals
FROM public.referrals r
LEFT JOIN public.profiles p ON r.referee_id = p.id;

-- Referral Stats Summary view
CREATE OR REPLACE VIEW public.referral_stats_summary WITH (security_invoker = true) AS
SELECT 
    r.referrer_id as user_id,
    COUNT(*) as total_referrals,
    COUNT(CASE WHEN p.has_claimed_welcome_bonus THEN 1 END) as completed_referrals,
    COALESCE(SUM(pt.amount), 0) as points_earned
FROM public.referrals r
LEFT JOIN public.profiles p ON r.referee_id = p.id
LEFT JOIN public.points_transactions pt ON pt.user_id = r.referrer_id AND pt.type = 'referral'
GROUP BY r.referrer_id;

-- Daily Task Completions view
CREATE OR REPLACE VIEW public.daily_task_completions WITH (security_invoker = true) AS
SELECT 
  date_trunc('day', created_at)::date as completion_date,
  count(*) as count
FROM public.task_submissions
WHERE status IN ('verified', 'approved')
GROUP BY 1
ORDER BY 1 DESC;

-- Repeatable Task Stats view
CREATE OR REPLACE VIEW public.repeatable_task_stats WITH (security_invoker = true) AS
SELECT 
  t.id,
  t.title,
  count(ts.id) as total_claims,
  count(distinct ts.user_id) as unique_users,
  round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
FROM public.tasks t
JOIN public.task_submissions ts ON t.id = ts.task_id
WHERE t.is_repeatable = true 
  AND ts.status IN ('verified', 'approved')
  AND ts.created_at > now() - interval '30 days'
GROUP BY 1, 2;

-- User Daily Task Counts view
CREATE OR REPLACE VIEW public.user_daily_task_counts WITH (security_invoker = true) AS
SELECT 
    user_id, 
    COUNT(*) as daily_count
FROM public.task_submissions
WHERE status = 'verified' 
  AND (created_at AT TIME ZONE 'UTC')::date = (CURRENT_DATE AT TIME ZONE 'UTC')
GROUP BY user_id;

-- 5. Stored Procedures & Functions

-- Role Checker
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  );
$$;

-- Username Availability Check
CREATE OR REPLACE FUNCTION public.check_username_available(_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE lower(trim(_username)) = lower(trim(p.username))
  );
END;
$$;

-- Referral Code Check
CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_username text;
BEGIN
    SELECT p.username
    INTO v_referrer_username
    FROM public.profiles p
    WHERE lower(p.referral_code) = lower(trim(_code))
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, false, 'Referral code not found.'::text;
        RETURN;
    END IF;

    RETURN QUERY SELECT v_referrer_username, true, 'Valid referral code.'::text;
END;
$$;

-- Increment Referral Clicks
CREATE OR REPLACE FUNCTION public.increment_referral_clicks(target_referral_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET referral_clicks = COALESCE(referral_clicks, 0) + 1
  WHERE lower(referral_code) = lower(trim(target_referral_code));
END;
$$;

-- Lookup Login Email by Username
CREATE OR REPLACE FUNCTION public.lookup_login_email(_username text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  SELECT email INTO v_email
  FROM public.profiles
  WHERE lower(username) = lower(trim(_username))
  LIMIT 1;
  RETURN v_email;
END;
$$;

-- Social Profile Completion Check
CREATE OR REPLACE FUNCTION public.has_completed_social_profile(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = _user_id
      AND (
        (twitter_handle IS NOT NULL AND twitter_handle != '') OR
        (telegram_handle IS NOT NULL AND telegram_handle != '')
      )
  );
$$;

-- Profile Completion Check
CREATE OR REPLACE FUNCTION public.is_profile_complete(p_profile_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_profile_id
      AND username IS NOT NULL
      AND full_name IS NOT NULL
  );
$$;

-- Handle New User Registration Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  meta_username TEXT;
  meta_full_name TEXT;
  meta_referred_by TEXT;
  target_referral_code TEXT;
  referrer_user_id UUID;
BEGIN
  meta_username := NULLIF(TRIM(new.raw_user_meta_data->>'username'), '');
  meta_full_name := NULLIF(TRIM(new.raw_user_meta_data->>'full_name'), '');
  meta_referred_by := NULLIF(TRIM(COALESCE(
    new.raw_user_meta_data->>'referral_code_used',
    new.raw_user_meta_data->>'referral_code',
    new.raw_user_meta_data->>'referred_by'
  )), '');

  target_referral_code := COALESCE(meta_username, substring(encode(gen_random_bytes(6), 'hex'), 1, 10));

  IF meta_referred_by IS NOT NULL THEN
    SELECT id INTO referrer_user_id FROM public.profiles 
    WHERE lower(referral_code) = lower(meta_referred_by) LIMIT 1;
  END IF;

  INSERT INTO public.profiles (
    id, email, username, full_name, referral_code, referral_code_used, referred_by
  )
  VALUES (
    new.id,
    new.email,
    meta_username,
    meta_full_name,
    target_referral_code,
    meta_referred_by,
    referrer_user_id
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = COALESCE(public.profiles.username, EXCLUDED.username),
    full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
    referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code);

  -- Assign default 'user' role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (new.id, 'user')
  ON CONFLICT (user_id, role) DO NOTHING;

  -- Create referral link record if valid
  IF referrer_user_id IS NOT NULL THEN
    INSERT INTO public.referrals (referee_id, referrer_id)
    VALUES (new.id, referrer_user_id)
    ON CONFLICT (referee_id) DO UPDATE SET referrer_id = EXCLUDED.referrer_id;
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Balance Sync Trigger Function
CREATE OR REPLACE FUNCTION public.update_user_points_balance()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.profiles
        SET points_balance = points_balance + NEW.amount
        WHERE id = NEW.user_id;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount
        WHERE id = OLD.user_id;
    ELSIF (TG_OP = 'UPDATE') THEN
        UPDATE public.profiles
        SET points_balance = points_balance - OLD.amount + NEW.amount
        WHERE id = NEW.user_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;
CREATE TRIGGER on_points_transaction_change
AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_user_points_balance();

-- Sync Points Balance manually
CREATE OR REPLACE FUNCTION public.sync_points_balance(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = COALESCE((
        SELECT SUM(amount) FROM public.points_transactions WHERE user_id = p_user_id
    ), 0)
    WHERE id = p_user_id;
END;
$$;

-- Welcome Bonus Claim Function
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile record;
    v_bonus_enabled boolean;
    v_referral_points_referrer integer;
    v_referral_points_referee integer;
    v_required_socials jsonb;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
    v_duplicate_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id FOR UPDATE;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'alreadyClaimed', true, 'message', 'Bonus already claimed');
    END IF;

    SELECT (value->>0)::boolean INTO v_bonus_enabled FROM public.app_settings WHERE key = 'welcome_bonus_enabled';
    SELECT (value->>0)::integer INTO v_referral_points_referee FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
    SELECT (value->>0)::integer INTO v_referral_points_referrer FROM public.app_settings WHERE key = 'welcome_bonus_amount_referrer';
    SELECT value INTO v_required_socials FROM public.app_settings WHERE key = 'welcome_bonus_required_socials';

    v_bonus_enabled := COALESCE(v_bonus_enabled, true);
    v_referral_points_referee := COALESCE(v_referral_points_referee, 50);
    v_referral_points_referrer := COALESCE(v_referral_points_referrer, 75);
    v_required_socials := COALESCE(v_required_socials, '["twitter", "telegram"]'::jsonb);

    IF NOT v_bonus_enabled THEN
        RETURN json_build_object('success', false, 'message', 'Welcome bonus program is currently disabled.');
    END IF;

    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    IF ('"twitter"'::jsonb <@ v_required_socials) AND (v_twitter_clean IS NULL OR v_twitter_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Twitter profile to be eligible.');
    END IF;

    IF ('"telegram"'::jsonb <@ v_required_socials) AND (v_telegram_clean IS NULL OR v_telegram_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Telegram profile to be eligible.');
    END IF;

    -- Prevent duplicate handles
    SELECT id INTO v_duplicate_id FROM public.profiles 
    WHERE id != _user_id 
      AND has_claimed_welcome_bonus = true 
      AND (
          (twitter_handle IS NOT NULL AND v_twitter_clean IS NOT NULL AND twitter_handle = v_twitter_clean) OR
          (telegram_handle IS NOT NULL AND v_telegram_clean IS NOT NULL AND telegram_handle = v_telegram_clean)
      )
    LIMIT 1;

    IF v_duplicate_id IS NOT NULL THEN
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (_user_id, 'social_duplicate', 'high', jsonb_build_object(
            'duplicate_user_id', v_duplicate_id,
            'twitter', v_twitter_clean,
            'telegram', v_telegram_clean
        ));
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Credit referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'welcome_bonus', 'Welcome bonus for completing your profile');

    -- Credit referrer
    IF v_profile.referred_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id::text);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$$;

-- Daily Reward Claim Function
CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_streak_record record;
    v_points_to_add integer := 5;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer := 1;
BEGIN
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text));

    SELECT * INTO v_streak_record 
    FROM public.user_streaks 
    WHERE user_id = _user_id;

    IF v_streak_record.last_activity_at IS NOT NULL THEN
        v_last_claim := v_streak_record.last_activity_at::date;
        IF v_last_claim = v_now::date THEN
            RETURN json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
        END IF;
        IF v_last_claim = (v_now::date - interval '1 day')::date THEN
            v_is_consecutive := true;
        END IF;
    END IF;

    IF v_is_consecutive THEN
        UPDATE public.user_streaks
        SET 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        WHERE user_id = _user_id
        RETURNING current_streak INTO v_result_streak;
    ELSE
        INSERT INTO public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        VALUES (_user_id, 1, 1, v_now)
        ON CONFLICT (user_id) DO UPDATE 
        SET 
            current_streak = 1,
            last_activity_at = v_now
        RETURNING current_streak INTO v_result_streak;
    END IF;

    IF v_result_streak = 1 THEN v_points_to_add := 5;
    ELSIF v_result_streak = 2 THEN v_points_to_add := 5;
    ELSIF v_result_streak = 3 THEN v_points_to_add := 10;
    ELSIF v_result_streak = 4 THEN v_points_to_add := 10;
    ELSIF v_result_streak = 5 THEN v_points_to_add := 15;
    ELSIF v_result_streak = 6 THEN v_points_to_add := 15;
    ELSE v_points_to_add := 20;
    END IF;

    INSERT INTO public.points_transactions (user_id, amount, type, description, status, created_at)
    VALUES (_user_id, v_points_to_add, 'streak', format('Day %s Daily Check-in Streak Bonus', v_result_streak), 'completed', v_now);

    INSERT INTO public.notifications (user_id, title, message, type, created_at)
    VALUES (_user_id, 'Daily Streak Bonus Claimed! 🔥', format('You claimed +%s PTS for maintaining your Day %s streak!', v_points_to_add, v_result_streak), 'streak', v_now);

    RETURN json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', format('Day %s streak bonus claimed! +%s points', v_result_streak, v_points_to_add)
    );
END;
$$;

-- Redeem Reward Function
CREATE OR REPLACE FUNCTION public.redeem_reward(_reward_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_cost integer;
  v_stock integer;
  v_active boolean;
  v_title text;
  v_balance integer;
  v_redemption_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT cost_points, stock_count, is_active, title
    INTO v_cost, v_stock, v_active, v_title
  FROM public.rewards WHERE id = _reward_id FOR UPDATE;

  IF NOT FOUND OR NOT v_active THEN
    RETURN jsonb_build_object('success', false, 'message', 'Reward not available');
  END IF;

  IF v_stock IS NOT NULL AND v_stock <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Reward is out of stock');
  END IF;

  SELECT points_balance INTO v_balance FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_cost THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient points');
  END IF;

  IF v_stock IS NOT NULL THEN
    UPDATE public.rewards SET stock_count = stock_count - 1 WHERE id = _reward_id;
  END IF;

  INSERT INTO public.redemptions (user_id, reward_id, status)
  VALUES (v_user_id, _reward_id, 'pending')
  RETURNING id INTO v_redemption_id;

  INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
  VALUES (v_user_id, -v_cost, 'spend', 'Redeemed reward: ' || v_title, v_redemption_id::text);

  RETURN jsonb_build_object('success', true, 'message', 'Redemption submitted', 'redemption_id', v_redemption_id);
END;
$$;

-- Process Redemption Status Change Function (Admin)
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(
    _redemption_id uuid,
    _new_status text,
    _rejection_reason text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_redemption record;
    v_reward record;
BEGIN
    IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: Admin role required');
    END IF;

    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Redemption record not found');
    END IF;

    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;

    -- If rejecting and was pending, refund points
    IF _new_status = 'rejected' AND v_redemption.status = 'pending' THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, v_reward.cost_points, 'redemption_refund', 'Refund for rejected redemption: ' || v_reward.title, _redemption_id::text);

        -- Restore stock
        IF v_reward.stock_count IS NOT NULL THEN
            UPDATE public.rewards SET stock_count = stock_count + 1 WHERE id = v_redemption.reward_id;
        END IF;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_redemption.user_id, 'Redemption Rejected', COALESCE(_rejection_reason, 'Your redemption request was rejected and points have been refunded.'), 'redemption');
    ELSIF _new_status = 'approved' AND v_redemption.status = 'pending' THEN
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_redemption.user_id, 'Redemption Approved! 🎉', 'Your reward "' || v_reward.title || '" has been approved!', 'redemption');
    END IF;

    UPDATE public.redemptions 
    SET status = _new_status,
        rejection_reason = _rejection_reason,
        updated_at = now()
    WHERE id = _redemption_id;

    RETURN json_build_object('success', true, 'message', 'Redemption updated to ' || _new_status);
END;
$$;

-- Submit Task Function
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_status text;
  v_daily_count integer;
  v_daily_limit integer := 10;
  v_is_repeatable boolean;
  v_verification_required boolean;
  v_last_submission_date date;
  v_points integer;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT COALESCE(
    CASE
      WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
      WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
      ELSE NULL
    END,
    10
  )
  INTO v_daily_limit
  FROM public.app_settings
  WHERE key = 'daily_task_limit'
  LIMIT 1;
  v_daily_limit := GREATEST(COALESCE(v_daily_limit, 10), 1);

  SELECT count(*) INTO v_daily_count
  FROM public.task_submissions
  WHERE user_id = _user_id
    AND status IN ('verified', 'approved')
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';

  IF v_daily_count >= v_daily_limit THEN
    RETURN json_build_object(
      'success', false,
      'message', format('Daily task limit reached (%s tasks max per day)', v_daily_limit)
    );
  END IF;

  SELECT is_repeatable, verification_required, points
  INTO v_is_repeatable, v_verification_required, v_points
  FROM public.tasks
  WHERE id = _task_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Task not found or inactive');
  END IF;

  SELECT status, (created_at AT TIME ZONE 'UTC')::date
  INTO v_existing_status, v_last_submission_date
  FROM public.task_submissions
  WHERE user_id = _user_id AND task_id = _task_id
  ORDER BY created_at DESC LIMIT 1;

  IF v_existing_status IN ('verified', 'approved') AND v_last_submission_date = (now() AT TIME ZONE 'UTC')::date THEN
    RETURN json_build_object('success', false, 'message', 'Task already completed today');
  END IF;
  IF v_existing_status IN ('verified', 'approved') AND NOT COALESCE(v_is_repeatable, false) THEN
    RETURN json_build_object('success', false, 'message', 'This task can only be completed once');
  END IF;
  IF v_existing_status = 'pending' THEN
    RETURN json_build_object('success', false, 'message', 'Task already pending verification');
  END IF;

  INSERT INTO public.task_submissions (user_id, task_id, status, admin_note, verified_at)
  VALUES (
    _user_id,
    _task_id,
    CASE WHEN COALESCE(v_verification_required, false) THEN 'pending' ELSE 'verified' END,
    NULL,
    CASE WHEN COALESCE(v_verification_required, false) THEN NULL ELSE now() END
  )
  ON CONFLICT (user_id, task_id) DO UPDATE
  SET status = EXCLUDED.status,
      created_at = now(),
      admin_note = NULL,
      verified_at = EXCLUDED.verified_at;

  IF NOT COALESCE(v_verification_required, false) THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
    VALUES (_user_id, v_points, 'earn', 'Completed task: ' || (SELECT title FROM public.tasks WHERE id = _task_id), _task_id::text);
  END IF;

  IF COALESCE(v_verification_required, false) THEN
    RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'Task completed! ' || v_points || ' points awarded.',
    'points', v_points
  );
END;
$$;

-- Verify Task Submission Function (Admin)
CREATE OR REPLACE FUNCTION public.verify_task_submission(_submission_id uuid, _approve boolean, _admin_note text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sub record;
    v_task record;
BEGIN
    IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator') OR public.has_role(auth.uid(), 'task_manager')) THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: Admin or Moderator role required');
    END IF;

    SELECT * INTO v_sub FROM public.task_submissions WHERE id = _submission_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Submission not found');
    END IF;

    SELECT * INTO v_task FROM public.tasks WHERE id = v_sub.task_id;

    IF _approve THEN
        UPDATE public.task_submissions
        SET status = 'verified', verified_at = now(), admin_note = _admin_note
        WHERE id = _submission_id;

        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_sub.user_id, v_task.points, 'earn', 'Task verified: ' || v_task.title, v_task.id::text);

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_sub.user_id, 'Task Approved! 🌟', 'Your submission for "' || v_task.title || '" was approved and you earned ' || v_task.points || ' PTS.', 'points');
    ELSE
        UPDATE public.task_submissions
        SET status = 'rejected', admin_note = _admin_note
        WHERE id = _submission_id;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_sub.user_id, 'Task Rejected', COALESCE(_admin_note, 'Your submission for "' || v_task.title || '" was not approved.'), 'task');
    END IF;

    RETURN json_build_object('success', true, 'status', CASE WHEN _approve THEN 'verified' ELSE 'rejected' END);
END;
$$;

-- Get My Referees Function
CREATE OR REPLACE FUNCTION public.get_my_referees()
RETURNS TABLE(
  id uuid,
  username text,
  full_name text,
  avatar_url text,
  has_social boolean,
  has_phone boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    (p.twitter_handle IS NOT NULL OR p.telegram_handle IS NOT NULL) AS has_social,
    (p.phone_number IS NOT NULL AND p.phone_number != '') AS has_phone,
    p.created_at
  FROM public.referrals r
  JOIN public.profiles p ON p.id = r.referee_id
  WHERE r.referrer_id = auth.uid()
  ORDER BY p.created_at DESC;
END;
$$;

-- Get Funnel Stats Function
CREATE OR REPLACE FUNCTION public.get_funnel_stats(start_date text, end_date text)
RETURNS TABLE(signups bigint, referrals bigint, bonuses bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz := start_date::timestamptz;
  v_end timestamptz := end_date::timestamptz;
BEGIN
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.profiles WHERE created_at >= v_start AND created_at <= v_end) as signups,
    (SELECT count(*) FROM public.referrals WHERE created_at >= v_start AND created_at <= v_end) as referrals,
    (SELECT count(*) FROM public.profiles WHERE has_claimed_welcome_bonus = true AND created_at >= v_start AND created_at <= v_end) as bonuses;
END;
$$;

-- Get Daily Task Completions Analytics Function
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date text,
  end_date text,
  filter_task_id text DEFAULT NULL,
  granularity text DEFAULT 'day'
)
RETURNS TABLE(completion_date text, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz := start_date::timestamptz;
  v_end timestamptz := end_date::timestamptz;
BEGIN
  RETURN QUERY
  SELECT 
    to_char(date_trunc(granularity, ts.created_at), 'YYYY-MM-DD') as completion_date,
    count(*)::bigint as count
  FROM public.task_submissions ts
  WHERE ts.status IN ('verified', 'approved')
    AND ts.created_at >= v_start
    AND ts.created_at <= v_end
    AND (filter_task_id IS NULL OR ts.task_id = filter_task_id::uuid)
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$$;

-- Get Repeatable Task Stats Analytics Function
CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date text,
  end_date text,
  filter_task_id text DEFAULT NULL
)
RETURNS TABLE(id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start timestamptz := start_date::timestamptz;
  v_end timestamptz := end_date::timestamptz;
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.title,
    count(ts.id)::bigint as total_claims,
    count(distinct ts.user_id)::bigint as unique_users,
    round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE t.is_repeatable = true 
    AND ts.status IN ('verified', 'approved')
    AND ts.created_at >= v_start
    AND ts.created_at <= v_end
    AND (filter_task_id IS NULL OR t.id = filter_task_id::uuid)
  GROUP BY 1, 2;
END;
$$;

-- Send User Notification Function
CREATE OR REPLACE FUNCTION public.send_user_notification(
  _user_id uuid,
  _title text,
  _message text,
  _type text DEFAULT 'info',
  _metadata jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type, metadata)
  VALUES (_user_id, _title, _message, _type, _metadata);

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Admin Adjust Points Function
CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
  p_target_user_id uuid,
  p_amount integer,
  p_action_type text,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin uuid := auth.uid();
  v_delta integer;
BEGIN
  IF v_admin IS NULL OR NOT public.has_role(v_admin, 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  v_delta := CASE WHEN p_action_type = 'debit' THEN -abs(p_amount) ELSE abs(p_amount) END;

  UPDATE public.profiles SET points_balance = points_balance + v_delta WHERE id = p_target_user_id;

  INSERT INTO public.points_transactions (user_id, amount, type, description)
  VALUES (p_target_user_id, v_delta, CASE WHEN v_delta < 0 THEN 'admin_debit' ELSE 'admin_credit' END, p_reason);

  INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
  VALUES (p_target_user_id, v_delta, p_reason, 'admin_adjust');

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
  VALUES (v_admin, 'points_adjustment', 'profiles', p_target_user_id::text, jsonb_build_object('amount', v_delta, 'reason', p_reason));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Video Watch Start Function
CREATE OR REPLACE FUNCTION public.start_video_watch_session(_task_id uuid, _user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task record;
    v_session_id uuid;
    v_min_seconds integer := 10;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT * INTO v_task FROM public.tasks
    WHERE id = _task_id AND is_active = true;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    UPDATE public.video_watch_sessions SET consumed = true
    WHERE user_id = _user_id AND task_id = _task_id AND consumed = false;

    INSERT INTO public.video_watch_sessions (user_id, task_id, min_watch_seconds)
    VALUES (_user_id, _task_id, v_min_seconds)
    RETURNING id INTO v_session_id;

    RETURN json_build_object('success', true, 'session_id', v_session_id, 'min_watch_seconds', v_min_seconds);
END;
$$;

-- Video Watch Record Function
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid, _session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamptz := now();
    v_consumed_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND user_id = _user_id AND task_id = _task_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Invalid watch session.');
    END IF;

    UPDATE public.video_watch_sessions SET consumed = true
    WHERE id = _session_id AND consumed = false
    RETURNING id INTO v_consumed_id;

    IF v_consumed_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'This watch session was already used.');
    END IF;

    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET watch_count = public.video_ad_progress.watch_count + 1, last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= COALESCE(v_task_record.video_ad_count, 1) THEN
        RETURN public.submit_task(_user_id, _task_id);
    END IF;

    RETURN json_build_object(
        'success', true,
        'current_count', v_progress_record.watch_count,
        'required_count', v_task_record.video_ad_count
    );
END;
$$;

-- 6. Row Level Security Policies

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signup_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_watch_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_ad_progress ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can read their own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));
CREATE POLICY "Admins can update all profiles" ON public.profiles FOR UPDATE TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- User Roles Policies
CREATE POLICY "Users can read their own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins can manage all roles" ON public.user_roles FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Tasks Policies
CREATE POLICY "Anyone can read active tasks" ON public.tasks FOR SELECT TO authenticated USING (is_active = TRUE);
CREATE POLICY "Public can view active tasks" ON public.tasks FOR SELECT TO anon USING (is_active = TRUE);
CREATE POLICY "Admins can manage all tasks" ON public.tasks FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'task_manager'));

-- Task Submissions Policies
CREATE POLICY "Users can read own submissions" ON public.task_submissions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can create own submissions" ON public.task_submissions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage task submissions" ON public.task_submissions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator') OR public.has_role(auth.uid(), 'task_manager'));

-- Points Transactions Policies
CREATE POLICY "Users can read their own transactions" ON public.points_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Admins can read all transactions" ON public.points_transactions FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));

-- Points Audit Logs Policies
CREATE POLICY "Admins can read points audit logs" ON public.points_audit_logs FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Admin Audit Logs Policies
CREATE POLICY "Admins can read admin audit logs" ON public.admin_audit_logs FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Rewards Policies
CREATE POLICY "Anyone can read active rewards" ON public.rewards FOR SELECT TO authenticated USING (is_active = TRUE);
CREATE POLICY "Public can read active rewards" ON public.rewards FOR SELECT TO anon USING (is_active = TRUE);
CREATE POLICY "Admins can manage rewards" ON public.rewards FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Redemptions Policies
CREATE POLICY "Users can read their own redemptions" ON public.redemptions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can insert redemptions" ON public.redemptions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage redemptions" ON public.redemptions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));

-- Notifications Policies
CREATE POLICY "Users can read their own notifications" ON public.notifications FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE TO authenticated USING (auth.uid() = user_id);

-- Fraud Flags Policies
CREATE POLICY "Admins can view fraud flags" ON public.fraud_flags FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));
CREATE POLICY "Admins can manage fraud flags" ON public.fraud_flags FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Role Permissions Policies
CREATE POLICY "Authenticated can read role permissions" ON public.role_permissions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage role permissions" ON public.role_permissions FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- App Settings Policies
CREATE POLICY "Authenticated can read settings" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can manage settings" ON public.app_settings FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- User Streaks Policies
CREATE POLICY "Users can read their own streak" ON public.user_streaks FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Referrals Policies
CREATE POLICY "Users can read their referrals" ON public.referrals FOR SELECT TO authenticated USING (auth.uid() = referrer_id OR auth.uid() = referee_id);
CREATE POLICY "Admins can read all referrals" ON public.referrals FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));

-- Analytics Events Policies
CREATE POLICY "Allow users to log analytics" ON public.analytics_events FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
CREATE POLICY "Admins can read analytics" ON public.analytics_events FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

-- Video Ad Policies
CREATE POLICY "Users can view own video progress" ON public.video_ad_progress FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can view own video sessions" ON public.video_watch_sessions FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- 7. Execute Grants for RPC Functions
GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_referees() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_funnel_stats(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(text, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) TO authenticated, service_role;

-- 8. Seed Initial Platform Settings & Starter Data

INSERT INTO public.app_settings (key, value, description)
VALUES 
('welcome_bonus_enabled', 'true'::jsonb, 'Enable or disable welcome bonus for new users'),
('welcome_bonus_amount_referee', '50'::jsonb, 'Points awarded to newly referred user'),
('welcome_bonus_amount_referrer', '75'::jsonb, 'Points awarded to inviter on referee verification'),
('welcome_bonus_required_socials', '["twitter", "telegram"]'::jsonb, 'Required social handles to claim welcome bonus'),
('daily_task_limit', '15'::jsonb, 'Maximum number of tasks a user can complete per day')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Starter Tasks
INSERT INTO public.tasks (title, description, points, category, icon_name, link_url, is_active, is_featured, is_repeatable, verification_required)
VALUES
('Follow Noble Gain on Twitter / X', 'Follow our official account @noblegain and stay updated.', 50, 'Social', 'Twitter', 'https://twitter.com', true, true, false, true),
('Join our Telegram Community', 'Join our official Telegram channel and chat with the community.', 50, 'Social', 'Send', 'https://t.me', true, true, false, true),
('Complete Profile Setup', 'Add your full name, avatar, and social handles in Settings.', 25, 'General', 'User', '/profile', true, false, false, false),
('Watch Short Video Ad', 'Watch a 15-second sponsor video to earn reward points.', 10, 'Videos', 'Play', NULL, true, false, true, false)
ON CONFLICT DO NOTHING;

-- Starter Rewards
INSERT INTO public.rewards (title, description, cost_points, category, stock_count, is_active)
VALUES
('$5 PayPal Cash', 'Redeem for $5 direct to your PayPal account.', 500, 'Cash', 100, true),
('$10 Amazon Gift Card', 'Redeem for a $10 digital Amazon gift code.', 1000, 'Gift Cards', 50, true),
('$20 Crypto (USDT)', 'Redeem for $20 USDT transferred directly to your wallet.', 2000, 'Crypto', 50, true)
ON CONFLICT DO NOTHING;
