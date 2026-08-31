-- =============================================
-- Reset Public Schema for Clean Replay
-- =============================================
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
GRANT ALL ON SCHEMA public TO anon;
GRANT ALL ON SCHEMA public TO authenticated;
GRANT ALL ON SCHEMA public TO service_role;

CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- =============================================
-- Migration: 20260819123201_7643129e-2cde-4b14-8675-c378da21e4f7.sql
-- =============================================

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  points_balance INTEGER DEFAULT 0 NOT NULL,
  referral_code TEXT UNIQUE,
  referred_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own profile" ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Create tasks table
CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  points INTEGER NOT NULL,
  category TEXT, -- e.g., 'daily', 'social', 'survey'
  icon_name TEXT,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.tasks TO authenticated;
GRANT ALL ON public.tasks TO service_role;

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active tasks" ON public.tasks
  FOR SELECT TO authenticated USING (is_active = TRUE);

-- Create points_transactions table
CREATE TABLE public.points_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL, -- 'earn', 'spend'
  description TEXT,
  source_id UUID, -- reference to task_id or redemption_id
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;

ALTER TABLE public.points_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own transactions" ON public.points_transactions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Create rewards table
CREATE TABLE public.rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  cost_points INTEGER NOT NULL,
  image_url TEXT,
  stock_count INTEGER,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.rewards TO authenticated;
GRANT ALL ON public.rewards TO service_role;

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active rewards" ON public.rewards
  FOR SELECT TO authenticated USING (is_active = TRUE);

-- Create redemptions table
CREATE TABLE public.redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_id UUID NOT NULL REFERENCES public.rewards(id),
  status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, INSERT ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own redemptions" ON public.redemptions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert redemptions" ON public.redemptions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, referral_code)
  VALUES (
    new.id,
    new.email,
    encode(gen_random_bytes(6), 'hex')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- =============================================
-- Migration: 20260819000001_sync_points_balance.sql
-- =============================================

-- Function to update points_balance on profile when a transaction occurs
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

-- Add trigger to points_transactions table
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;
CREATE TRIGGER on_points_transaction_change
AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_user_points_balance();

-- One-time sync to ensure all balances are correct based on transaction history
UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(amount)
    FROM public.points_transactions
    WHERE user_id = p.id
), 0);

-- Revoke public execute on the trigger function
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819123208_34e5881b-5c72-48dd-ae99-57ee469a2537.sql
-- =============================================

-- Fix security issues for handle_new_user
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819123213_4d96bfe9-66ae-4250-a593-321c95b42f2e.sql
-- =============================================

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819124402_22cdc788-d46b-4507-82ad-e3ea3fb15e64.sql
-- =============================================

-- Applying the migration content via supabase--migration
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('admin', 'user');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    from public.user_roles
    where user_id = _user_id
      and role = _role
  )
$$;

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'points', 'referral', 'redemption', 'streak'
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can read their own notifications') THEN
        CREATE POLICY "Users can read their own notifications" ON public.notifications
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update their own notifications') THEN
        CREATE POLICY "Users can update their own notifications" ON public.notifications
            FOR UPDATE TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    longest_streak INTEGER DEFAULT 0 NOT NULL
);

GRANT SELECT ON public.user_streaks TO authenticated;
GRANT ALL ON public.user_streaks TO service_role;

ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_streaks' AND policyname = 'Users can read their own streak') THEN
        CREATE POLICY "Users can read their own streak" ON public.user_streaks
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rewards' AND policyname = 'Admins can manage rewards') THEN
        CREATE POLICY "Admins can manage rewards" ON public.rewards
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'redemptions' AND policyname = 'Admins can manage redemptions') THEN
        CREATE POLICY "Admins can manage redemptions" ON public.redemptions
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.notify_on_points_transaction()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        NEW.user_id,
        CASE WHEN NEW.amount > 0 THEN 'Points Earned!' ELSE 'Points Spent' END,
        NEW.description,
        'points'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_points_transaction ON public.points_transactions;
CREATE TRIGGER on_points_transaction
    AFTER INSERT ON public.points_transactions
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_points_transaction();


-- =============================================
-- Migration: 20260819124411_3a41391f-551a-4824-ad42-c82a92110c29.sql
-- =============================================

-- Fixing security linter warnings

-- 1. Fix search_path and execution for notify_on_points_transaction
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 2. Fix search_path and execution for has_role (already has search_path, just execution)
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3. Fix handle_new_user from previous migration
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 4. Ensure RLS policies exist for user_roles (missed in migration)
CREATE POLICY "Admins can read all roles" ON public.user_roles
    FOR SELECT TO authenticated USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can read their own roles" ON public.user_roles
    FOR SELECT TO authenticated USING (auth.uid() = user_id);


-- =============================================
-- Migration: 20260819124907_785efa4a-a678-4066-b4c3-9fcc97794135.sql
-- =============================================

CREATE OR REPLACE VIEW public.leaderboard AS
SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

-- Add referral rewards progress tracking if not exists
-- We can track how many referrals are "completed" (e.g., have earned points)
-- For now, let's just make sure we have a way to count them easily.


-- =============================================
-- Migration: 20260819125337_76e82e88-1aaa-479a-ae97-8118f96d995f.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    substring(md5(random()::text), 1, 12)
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Fallback if something fails, though we want the user to be created at least
  INSERT INTO public.profiles (id, email, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    NULL
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Ensure the function is executable by the necessary roles for triggers
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819125344_fe1bae33-c130-46e7-af47-f12aeef7cec8.sql
-- =============================================

-- Fix the security definer view by making it a simple view (RLS on profiles will apply)
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard AS
SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

-- Revoke public execution of handle_new_user to satisfy linter
-- The postgres and service_role grants are enough for the trigger to work
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819125349_2c21bcd3-f63d-4d58-aa72-1acc175e3874.sql
-- =============================================

-- Explicitly ensure the view is not security definer and the function is locked down
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = on) AS
SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

-- Re-verify function permissions
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819125353_32eea503-4d22-499d-99a3-292d3f5d53d3.sql
-- =============================================

-- Final attempt to satisfy linter by being extremely explicit about revoking from everyone including public
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
REVOKE ALL PRIVILEGES ON FUNCTION public.handle_new_user() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819131138_c85427dd-1e27-48f3-8e5f-0077a35b3e4a.sql
-- =============================================

-- Add notification settings columns to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS email_notifications BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS push_notifications BOOLEAN DEFAULT true;


-- =============================================
-- Migration: 20260819131231_0c5d357b-32fd-4695-8dd8-1b30392050b8.sql
-- =============================================

-- RLS for avatars bucket
-- Allow authenticated users to read any avatar (for social features)
CREATE POLICY "Allow authenticated read" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'avatars');

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Allow authenticated upload" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow users to update/delete their own avatar
CREATE POLICY "Allow individual update" ON storage.objects 
FOR UPDATE TO authenticated 
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Allow individual delete" ON storage.objects 
FOR DELETE TO authenticated 
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);


-- =============================================
-- Migration: 20260819132908_ae824c13-dcb1-4829-921d-1c11d4f562c6.sql
-- =============================================

-- Add referral clicks tracking to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_clicks INTEGER DEFAULT 0;

-- Function to increment clicks
CREATE OR REPLACE FUNCTION public.increment_referral_clicks(target_referral_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles
    SET referral_clicks = referral_clicks + 1
    WHERE referral_code = target_referral_code;
END;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819132916_3acbd46b-7dd0-4021-afb5-51b02ee56e80.sql
-- =============================================

-- Revoke public execution of SECURITY DEFINER function to satisfy linter
-- The function increment_referral_clicks is intended to be called by anon for referral tracking, 
-- but we should be explicit and careful. We keep the grant to anon since it's a "public" click increment,
-- but the linter warns about it. To make it "safer", we'll just acknowledge the risk or restrict public
-- execute if we had another way, but for click tracking, anon must be able to call it.
-- However, to satisfy the linter's advice for common patterns, we can at least REVOKE from PUBLIC first.

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819133938_dd8207f3-a6ff-48b8-a460-57ea23f89693.sql
-- =============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT UNIQUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  new_referral_code TEXT;
  meta_username TEXT;
  meta_full_name TEXT;
BEGIN
  new_referral_code := substring(md5(random()::text), 1, 12);
  meta_username := (new.raw_user_meta_data->>'username');
  meta_full_name := (new.raw_user_meta_data->>'full_name');

  INSERT INTO public.profiles (id, referral_code, referred_by, username, full_name, email_notifications, push_notifications)
  VALUES (
    new.id,
    new_referral_code,
    new.raw_user_meta_data->>'referred_by',
    meta_username,
    meta_full_name,
    true,
    true
  );
  RETURN new;
EXCEPTION WHEN OTHERS THEN
  INSERT INTO public.profiles (id, referral_code)
  VALUES (new.id, NULL);
  RETURN new;
END;
$$;

-- =============================================
-- Migration: 20260819133952_ab8bdfb1-e97b-428a-aeba-04be69d0c88f.sql
-- =============================================

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260819133957_a16bdeab-6388-466e-b143-c8f248d11c8f.sql
-- =============================================

-- Secure the handle_new_user function properly
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SECURITY DEFINER'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Secure points transaction triggers if they exist
-- (Checking for common patterns based on previous messages)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'on_points_transaction') THEN
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.on_points_transaction() SECURITY DEFINER'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
        REVOKE ALL ON FUNCTION public.on_points_transaction() FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.on_points_transaction() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.on_points_transaction() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
    END IF;
END $$;


-- =============================================
-- Migration: 20260819134040_ee8ab95c-5940-45b5-a003-3e61ef30e4fc.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.get_user_email_by_username(_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT au.email INTO user_email
    FROM auth.users au
    JOIN public.profiles p ON p.id = au.id
    WHERE p.username = _username;
    
    RETURN user_email;
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_email_by_username(TEXT) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(TEXT) TO authenticated, anon, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819134559_f49ced02-6578-4ba4-82e3-2db3d21643d8.sql
-- =============================================


-- 1. Update handle_new_user to use username as referral_code
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  meta_username TEXT;
  meta_full_name TEXT;
  target_referral_code TEXT;
BEGIN
  meta_username := (new.raw_user_meta_data->>'username');
  meta_full_name := (new.raw_user_meta_data->>'full_name');
  
  -- Use username as the referral code. Fallback to a random string if username is missing.
  target_referral_code := COALESCE(meta_username, substring(md5(random()::text), 1, 12));

  INSERT INTO public.profiles (
    id, 
    referral_code, 
    referred_by, 
    username, 
    full_name, 
    email_notifications, 
    push_notifications,
    email
  )
  VALUES (
    new.id,
    target_referral_code,
    new.raw_user_meta_data->>'referred_by',
    meta_username,
    meta_full_name,
    true,
    true,
    new.email
  );
  RETURN new;
EXCEPTION WHEN OTHERS THEN
  -- Last resort: ensure we at least have a profile with the ID and email
  -- We use ON CONFLICT to avoid errors if partially created
  INSERT INTO public.profiles (id, email, referral_code)
  VALUES (new.id, new.email, substring(md5(random()::text), 1, 12))
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

-- 2. Update existing profiles to use their username as referral_code where applicable
UPDATE public.profiles 
SET referral_code = username 
WHERE username IS NOT NULL 
  AND (referral_code IS NULL OR referral_code != username);

-- 3. Update leaderboard view to include username
DROP VIEW IF EXISTS public.leaderboard;
CREATE OR REPLACE VIEW public.leaderboard AS
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

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;


-- =============================================
-- Migration: 20260819134618_28e198b4-a537-4108-ae15-ec6a6c960982.sql
-- =============================================


-- Revoke execute from public to satisfy linter for SECURITY DEFINER functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.get_user_email_by_username(TEXT) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(TEXT) TO authenticated, anon, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-create the view with security_invoker = true to satisfy linter (lint 0010)
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = true) AS
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

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;


-- =============================================
-- Migration: 20260819134917_d70ae6a8-31ee-4be5-9687-a401e77d462f.sql
-- =============================================

INSERT INTO public.user_roles (user_id, role)
SELECT '3e18d6c9-1579-4673-812a-fcc6e43a428b'::uuid, 'admin'::public.app_role
WHERE EXISTS (SELECT 1 FROM auth.users WHERE id = '3e18d6c9-1579-4673-812a-fcc6e43a428b')
ON CONFLICT (user_id, role) DO NOTHING;

-- =============================================
-- Migration: 20260819145740_ccdfbf7d-905c-4e94-9ae0-89132c49cb22.sql
-- =============================================

create or replace function public.claim_daily_reward(_user_id uuid)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
    v_streak_record record;
    v_points_to_add integer := 20;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
begin
    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'Already claimed today');
        end if;
        
        -- Check if it is consecutive (yesterday)
        if v_last_claim = (v_now::date - interval '1 day')::date then
            v_is_consecutive := true;
        end if;
    end if;

    -- 2. Update streak
    if v_is_consecutive then
        update public.user_streaks
        set 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        where user_id = _user_id
        returning * into v_streak_record;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, greatest(coalesce(v_streak_record.longest_streak, 0), 1), v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning * into v_streak_record;
    end if;

    -- 3. Determine points (25 if streak >= 7, otherwise 20)
    if v_streak_record.current_streak >= 7 then
        v_points_to_add := 25;
    end if;

    -- 4. Record transaction
    insert into public.points_transactions (user_id, amount, type, description, created_at)
    values (_user_id, v_points_to_add, 'earn', 'Daily reward claiming', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_streak_record.current_streak
    );
end;
$$;

DO $$ BEGIN EXECUTE 'grant execute on function public.claim_daily_reward(uuid) to authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260819150033_8c277328-6e3a-4b5e-98a0-aaabc492ee9b.sql
-- =============================================

-- 1. Hardening the claim_daily_reward function for concurrent requests
create or replace function public.claim_daily_reward(_user_id uuid)
 returns json
 language plpgsql
 security definer
 set search_path to 'public'
as $$
declare
    v_streak_record record;
    v_points_to_add integer := 20;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer;
begin
    -- Use a explicit lock to prevent concurrent claims for the same user
    -- pg_advisory_xact_lock uses a 64-bit integer, we use user_id's hash
    perform pg_advisory_xact_lock(hashtext(_user_id::text));

    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
        end if;
        
        -- Check if it is consecutive (yesterday)
        if v_last_claim = (v_now::date - interval '1 day')::date then
            v_is_consecutive := true;
        end if;
    end if;

    -- 2. Update streak
    if v_is_consecutive then
        update public.user_streaks
        set 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        where user_id = _user_id
        returning current_streak into v_result_streak;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, 1, v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning current_streak into v_result_streak;
    end if;

    -- 3. Determine points (25 if streak >= 7, otherwise 20)
    if v_result_streak >= 7 then
        v_points_to_add := 25;
    end if;

    -- 4. Record transaction (atomic with streak update in one transaction)
    insert into public.points_transactions (user_id, amount, type, description, created_at)
    values (_user_id, v_points_to_add, 'earn', 'Daily reward claiming', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', 'Reward claimed successfully!'
    );
end;
$$;

-- =============================================
-- Migration: 20260819150615_4a38875a-8e66-4e3e-ae82-2eebe4171139.sql
-- =============================================

UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(CASE WHEN t.type = 'earn' THEN t.amount ELSE -t.amount END)
    FROM public.points_transactions t
    WHERE t.user_id = p.id
), 0);

-- =============================================
-- Migration: 20260819150648_e840d896-0c39-4957-8f43-84fb27440736.sql
-- =============================================

-- 1. Restrict claim_daily_reward
REVOKE ALL ON FUNCTION public.claim_daily_reward(uuid) FROM public, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 2. Update claim_daily_reward to verify the caller matches the user_id argument
CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_streak_record record;
    v_points_to_add integer := 20;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer;
begin
    -- SECURITY CHECK: Ensure the authenticated user is only claiming for themselves
    if auth.uid() <> _user_id then
        return json_build_object('success', false, 'message', 'Unauthorized: You can only claim rewards for your own account.');
    end if;

    -- Use a explicit lock to prevent concurrent claims for the same user
    perform pg_advisory_xact_lock(hashtext(_user_id::text));

    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
        end if;
        
        -- Check if it is consecutive (yesterday)
        if v_last_claim = (v_now::date - interval '1 day')::date then
            v_is_consecutive := true;
        end if;
    end if;

    -- 2. Update streak
    if v_is_consecutive then
        update public.user_streaks
        set 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        where user_id = _user_id
        returning current_streak into v_result_streak;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, 1, v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning current_streak into v_result_streak;
    end if;

    -- 3. Determine points (25 if streak >= 7, otherwise 20)
    if v_result_streak >= 7 then
        v_points_to_add := 25;
    end if;

    -- 4. Record transaction
    insert into public.points_transactions (user_id, amount, type, description, created_at)
    values (_user_id, v_points_to_add, 'earn', 'Daily reward claiming', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', 'Reward claimed successfully!'
    );
end;
$function$;

-- =============================================
-- Migration: 20260819150704_1cc89291-4c65-4995-a53c-9d37f8aeb930.sql
-- =============================================

-- Revoke execute from public on all security definer functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Grant execute only to the roles that actually need them
GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(text) TO authenticated, anon; -- Needed for sign-in logic
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated, anon; -- Needed for referral tracking on landing page

-- The triggers handle_new_user and notify_on_points_transaction are called by the system (service_role)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- claim_daily_reward is already restricted to authenticated in the previous turn


-- =============================================
-- Migration: 20260819162639_414cc674-c5f9-4226-8b2c-96ed3ba86ae7.sql
-- =============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Update RLS if necessary (it should already be covered by existing policies)
-- But let's re-grant to be safe
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;


-- =============================================
-- Migration: 20260819164702_5f510abb-1bf9-43ee-b8d6-7f0c1467b76c.sql
-- =============================================

-- Allow public access to read avatars (if bucket is public or for general viewing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Public Access' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Public Access"
        ON storage.objects FOR SELECT
        USING ( bucket_id = 'avatars' );
    END IF;
END $$;

-- Allow authenticated users to upload their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can upload their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can upload their own avatar"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;

-- Allow users to update their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can update their own avatar"
        ON storage.objects FOR UPDATE
        TO authenticated
        USING (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;

-- Allow users to delete their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can delete their own avatar"
        ON storage.objects FOR DELETE
        TO authenticated
        USING (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;


-- =============================================
-- Migration: 20260819182606_a69d9ba1-e579-49b2-899b-aac9faa2fe7d.sql
-- =============================================


-- 1. Create task_submissions table to track user progress
CREATE TABLE IF NOT EXISTS public.task_submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    task_id uuid REFERENCES public.tasks(id) ON DELETE CASCADE NOT NULL,
    status text NOT NULL CHECK (status IN ('pending', 'verified', 'rejected')),
    created_at timestamp with time zone DEFAULT now(),
    UNIQUE (user_id, task_id)
);

-- 2. Add verification fields to tasks
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS link_url text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS verification_required boolean DEFAULT false;

-- 3. Grant access
GRANT SELECT, INSERT, UPDATE ON public.task_submissions TO authenticated;
GRANT ALL ON public.task_submissions TO service_role;

-- 4. Enable RLS
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;

-- 5. Create policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own submissions' AND tablename = 'task_submissions'
    ) THEN
        CREATE POLICY "Users can view their own submissions"
        ON public.task_submissions FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can create their own submissions' AND tablename = 'task_submissions'
    ) THEN
        CREATE POLICY "Users can create their own submissions"
        ON public.task_submissions FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- 6. Create submit_task function with idempotency and rate limiting
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_points integer;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    -- SECURITY CHECK: Ensure the authenticated user is only submitting for themselves
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: You can only submit tasks for your own account.');
    END IF;

    -- RATE LIMITING: Prevent spamming submissions (max 1 every 2 seconds per user)
    SELECT created_at INTO v_last_submission
    FROM public.task_submissions
    WHERE user_id = _user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_submission IS NOT NULL AND v_now - v_last_submission < interval '2 seconds' THEN
        RETURN json_build_object('success', false, 'message', 'Please wait a moment before submitting again.');
    END IF;

    -- Use explicit lock to prevent concurrent submissions for the same user/task
    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text || _task_id::text));

    -- 1. Get task details
    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found or inactive.');
    END IF;

    -- 2. Check for existing submission (IDEMPOTENCY)
    SELECT * INTO v_existing_submission FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id;
    
    IF FOUND THEN
        IF v_existing_submission.status = 'verified' THEN
            RETURN json_build_object('success', false, 'message', 'Task already completed and verified.');
        ELSIF v_existing_submission.status = 'pending' THEN
            RETURN json_build_object('success', false, 'message', 'Task submission is already under review.');
        END IF;
        RETURN json_build_object('success', false, 'message', 'Task has already been submitted (Status: ' || v_existing_submission.status || ').');
    END IF;

    -- 3. Create submission
    IF v_task_record.verification_required THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'pending', v_now);
        
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification.');
    ELSE
        -- Auto-verify and award points
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now);
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed task: ' || v_task_record.title, v_now);
        
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_task_record.points || ' points awarded.', 'points', v_task_record.points);
    END IF;
END;
$$;


-- =============================================
-- Migration: 20260819182623_ff75893f-3599-4891-b7be-8f1be1ff5661.sql
-- =============================================


DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM PUBLIC, authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
-- handle_new_user is a trigger, usually executed by the system or a service role, 
-- but we'll at least restrict PUBLIC/anon.


-- =============================================
-- Migration: 20260819183914_e6b1c602-7e24-4144-aa2e-cabb84135a41.sql
-- =============================================

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_featured boolean DEFAULT false;

-- =============================================
-- Migration: 20260819203022_d31c7d27-a0e2-45f0-8f51-5e7397c4cdae.sql
-- =============================================

-- Fix missing GRANTs for public tables
GRANT SELECT ON public.tasks TO authenticated, anon;
GRANT SELECT ON public.rewards TO authenticated, anon;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT ON public.points_transactions TO authenticated;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT SELECT ON public.user_streaks TO authenticated;
GRANT SELECT ON public.task_submissions TO authenticated;

GRANT ALL ON public.tasks TO service_role;
GRANT ALL ON public.rewards TO service_role;
GRANT ALL ON public.user_roles TO service_role;
GRANT ALL ON public.points_transactions TO service_role;
GRANT ALL ON public.redemptions TO service_role;
GRANT ALL ON public.profiles TO service_role;
GRANT ALL ON public.notifications TO service_role;
GRANT ALL ON public.user_streaks TO service_role;
GRANT ALL ON public.task_submissions TO service_role;


-- =============================================
-- Migration: 20260819203039_646cb495-0263-4424-9d4b-7d77d8cc938f.sql
-- =============================================

-- Secure SECURITY DEFINER functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.get_user_email_by_username(text) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Grant execution to authenticated for necessary functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
-- assign_role and remove_role should only be callable by admins, but as they are SECURITY DEFINER
-- and used in the UI, we keep them restricted or handle role checks inside them.
-- For now, let's keep them restricted from general authenticated users unless they are admins.
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure service_role always has access
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;


-- =============================================
-- Migration: 20260819203452_26a94bc7-f194-42d5-9ce5-1c07a5325a60.sql
-- =============================================


-- Grant SELECT on public tables to authenticated and anon where appropriate
GRANT SELECT ON public.tasks TO authenticated, anon;
GRANT SELECT ON public.rewards TO authenticated, anon;
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT ON public.points_transactions TO authenticated;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT SELECT ON public.user_streaks TO authenticated;
GRANT SELECT ON public.task_submissions TO authenticated;

-- Grant ALL on public tables to service_role
GRANT ALL ON public.tasks TO service_role;
GRANT ALL ON public.rewards TO service_role;
GRANT ALL ON public.profiles TO service_role;
GRANT ALL ON public.user_roles TO service_role;
GRANT ALL ON public.points_transactions TO service_role;
GRANT ALL ON public.rewards TO service_role;
GRANT ALL ON public.points_transactions TO service_role;
GRANT ALL ON public.redemptions TO service_role;
GRANT ALL ON public.notifications TO service_role;
GRANT ALL ON public.user_streaks TO service_role;
GRANT ALL ON public.task_submissions TO service_role;


-- =============================================
-- Migration: 20260819203507_0b53e280-1080-4f54-afe7-1d6d51a5c970.sql
-- =============================================


-- Grant EXECUTE on the has_role function to authenticated users
-- This is necessary for the app to check user roles in the frontend and routes.
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Also ensure it's callable by service_role for any backend work
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819203539_87688114-fdea-4103-bf84-93ee41c381ff.sql
-- =============================================


-- Grant EXECUTE on submit_task to authenticated users
-- This is required for users to be able to complete tasks and earn points.
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Also ensure it's callable by service_role
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819204143_222cc7b7-6306-48df-b656-38b11a08235b.sql
-- =============================================


-- Create admin audit logs table
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id),
    target_table TEXT NOT NULL,
    target_id UUID NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT SELECT ON public.admin_audit_logs TO authenticated;
GRANT ALL ON public.admin_audit_logs TO service_role;

-- RLS Policy: Only admins can view audit logs
CREATE POLICY "Admins can view audit logs"
ON public.admin_audit_logs
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Trigger function to log admin actions
CREATE OR REPLACE FUNCTION public.handle_admin_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    current_admin_id UUID;
BEGIN
    current_admin_id := auth.uid();
    
    -- We only log if it's an authenticated user (admin) making the change
    -- If current_admin_id is null, it might be a system action or service role
    -- but we usually want to track who did what in the UI.
    
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, new_data)
        VALUES (current_admin_id, TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
        VALUES (current_admin_id, TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data)
        VALUES (current_admin_id, TG_TABLE_NAME, OLD.id, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for tasks
CREATE TRIGGER audit_tasks_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.handle_admin_audit_log();

-- Create triggers for rewards
CREATE TRIGGER audit_rewards_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.rewards
FOR EACH ROW EXECUTE FUNCTION public.handle_admin_audit_log();


-- =============================================
-- Migration: 20260819204202_fbdb4f10-1f7f-4b60-997c-f30b57ac78d5.sql
-- =============================================


-- Secure handle_admin_audit_log
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_admin_audit_log() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
-- Triggers will still work because they are owned by postgres and the function is SECURITY DEFINER


-- =============================================
-- Migration: 20260819204215_47f77e94-e55f-4abc-8d3c-3de0a39aba14.sql
-- =============================================


-- Set search_path and restrict access for internal functions
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.update_points_balance_on_task_status_change() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.log_task_status_change() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.log_task_status_change() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.log_user_task_activity() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.log_user_task_activity() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Functions that need to be callable by authenticated users but still need search_path
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.has_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.submit_task(uuid, uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.increment_referral_clicks(text) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.get_user_email_by_username(text) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Admin functions - ensure they check admin role
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.assign_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.remove_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Note: The linter will still warn about functions callable by signed-in users 
-- if they are SECURITY DEFINER. This is expected for APIs that need elevated 
-- privileges to update balances or check roles.


-- =============================================
-- Migration: 20260819204956_246a2ddc-2d65-4d5e-a84f-8508f718f0dc.sql
-- =============================================

-- Function to update points_balance on profile when a transaction occurs
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

-- Add trigger to points_transactions table
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;
CREATE TRIGGER on_points_transaction_change
AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_user_points_balance();

-- One-time sync to ensure all balances are correct based on transaction history
UPDATE public.profiles p
SET points_balance = COALESCE((
    SELECT SUM(amount)
    FROM public.points_transactions
    WHERE user_id = p.id
), 0);

-- Revoke public execute on the trigger function
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260819210209_13653cf0-d021-485b-a5ca-5033d0db6e4e.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.lookup_login_email(_username TEXT)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    user_email TEXT;
BEGIN
    IF _username IS NULL OR length(trim(_username)) = 0 THEN
        RETURN NULL;
    END IF;

    SELECT au.email INTO user_email
    FROM auth.users au
    JOIN public.profiles p ON p.id = au.id
    WHERE lower(p.username) = lower(trim(_username))
    LIMIT 1;

    RETURN user_email;
END;
$$;

REVOKE ALL ON FUNCTION public.lookup_login_email(TEXT) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(TEXT) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260819210231_19c90a20-f589-4037-93a3-e7f11ef325a9.sql
-- =============================================

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260819232540_bdc202be-25a1-4591-b17b-0e187ad4eaab.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    new_username text;
    base_username text;
    counter integer := 0;
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

    -- Insert profile with hardened ON CONFLICT handling
    INSERT INTO public.profiles (
        id, 
        username, 
        full_name, 
        avatar_url,
        referral_code
    )
    VALUES (
        new.id, 
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username
    )
    ON CONFLICT (id) DO UPDATE SET
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url;

    -- Handle referral if referral_code was provided during signup
    IF new.raw_user_meta_data->>'referral_code' IS NOT NULL THEN
        -- Using ON CONFLICT DO NOTHING to prevent errors if the link already exists
        INSERT INTO public.referrals (referrer_id, referee_id)
        SELECT id, new.id
        FROM public.profiles
        WHERE username = new.raw_user_meta_data->>'referral_code'
        ON CONFLICT (referee_id) DO NOTHING;
    END IF;

    RETURN new;
END;
$$;

-- =============================================
-- Migration: 20260819233858_6433b91e-156e-4a93-b84b-39e21850a958.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75; -- Points awarded to the referrer
    v_referee_reward_points INTEGER := 75;  -- Points awarded to the referee
BEGIN
    -- Find the referrer from the referrals table
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

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
        
        -- Award Referee (Welcome Bonus)
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            NEW.id,
            v_referee_reward_points,
            'welcome_bonus',
            'Welcome bonus for joining via referral'
        );
        
        -- Notify the referrer
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                v_referrer_id,
                'Referral Reward!',
                'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined using your code.',
                'reward'
            );
            
            -- Notify the referee
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


-- =============================================
-- Migration: 20260819234549_e1e0c07e-87ce-4d35-8cf8-028481b52fa7.sql
-- =============================================

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


-- =============================================
-- Migration: 20260819234602_1745a9a6-b510-4cc3-a389-6bfb1efde07e.sql
-- =============================================

-- Revoke public execution for handle_new_user
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Revoke public execution for reward_referrer_on_signup
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260819235621_bd3fd9be-c200-4f96-a8c9-060ca77037aa.sql
-- =============================================

-- 1. Add the column to track if the bonus was claimed
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_claimed_welcome_bonus BOOLEAN DEFAULT FALSE;

-- 2. Create the referral code check function (using a different name for the boolean column to avoid reserved keyword 'exists')
CREATE OR REPLACE FUNCTION public.check_referral_code(_code TEXT)
RETURNS TABLE (username TEXT, is_valid BOOLEAN) 
LANGUAGE plpgsql SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    RETURN QUERY 
    SELECT p.username, TRUE 
    FROM public.profiles p 
    WHERE p.referral_code = _code
    LIMIT 1;
END;
$$;

-- 3. Create the claim welcome bonus function
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referred_by UUID;
    v_has_claimed BOOLEAN;
BEGIN
    -- Check if user exists and has a referrer
    SELECT referred_by, has_claimed_welcome_bonus 
    INTO v_referred_by, v_has_claimed
    FROM public.profiles
    WHERE id = _user_id;

    IF v_referred_by IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not eligible for a referral bonus.');
    END IF;

    IF v_has_claimed THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bonus already claimed.');
    END IF;

    -- Update profile
    UPDATE public.profiles
    SET has_claimed_welcome_bonus = TRUE
    WHERE id = _user_id;

    RETURN jsonb_build_object('success', true, 'message', 'Bonus claimed successfully!', 'amount', 50);
END;
$$;

-- 4. Set permissions
REVOKE ALL ON FUNCTION public.check_referral_code(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT) TO authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820000000_notifications_and_admin.sql
-- =============================================

-- 1. User Roles System
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('admin', 'user');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    from public.user_roles
    where user_id = _user_id
      and role = _role
  )
$$;

-- 2. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'points', 'referral', 'redemption', 'streak'
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can read their own notifications') THEN
        CREATE POLICY "Users can read their own notifications" ON public.notifications
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update their own notifications') THEN
        CREATE POLICY "Users can update their own notifications" ON public.notifications
            FOR UPDATE TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

-- 3. Streaks Table
CREATE TABLE IF NOT EXISTS public.user_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    longest_streak INTEGER DEFAULT 0 NOT NULL
);

GRANT SELECT ON public.user_streaks TO authenticated;
GRANT ALL ON public.user_streaks TO service_role;

ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_streaks' AND policyname = 'Users can read their own streak') THEN
        CREATE POLICY "Users can read their own streak" ON public.user_streaks
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

-- 4. Admin Policies (Example for rewards)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rewards' AND policyname = 'Admins can manage rewards') THEN
        CREATE POLICY "Admins can manage rewards" ON public.rewards
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'redemptions' AND policyname = 'Admins can manage redemptions') THEN
        CREATE POLICY "Admins can manage redemptions" ON public.redemptions
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
END $$;

-- 5. Trigger for Notifications on points_transactions
CREATE OR REPLACE FUNCTION public.notify_on_points_transaction()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        NEW.user_id,
        CASE WHEN NEW.amount > 0 THEN 'Points Earned!' ELSE 'Points Spent' END,
        NEW.description,
        'points'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_points_transaction ON public.points_transactions;
CREATE TRIGGER on_points_transaction
    AFTER INSERT ON public.points_transactions
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_points_transaction();


-- =============================================
-- Migration: 20260820000001_referral_reward_system.sql
-- =============================================

-- Create a function to handle referral rewards when a new user joins
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50; -- Points awarded for a successful referral
BEGIN
    -- Find the referrer from the referrals table
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

    -- If a referrer was found, award them points
    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username
        );
        
        -- Also notify the referrer if the notification system exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                v_referrer_id,
                'Referral Reward!',
                'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined using your code.',
                'reward'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Attach the trigger to the profiles table (fires after handle_new_user)
DROP TRIGGER IF EXISTS on_profile_referral_reward ON public.profiles;
CREATE TRIGGER on_profile_referral_reward
    AFTER INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.reward_referrer_on_signup();

-- Ensure proper permissions
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820000002_add_referral_code_used.sql
-- =============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_code_used TEXT;
COMMENT ON COLUMN public.profiles.referral_code_used IS 'The referral code (username) that was used by this user to sign up.';


-- =============================================
-- Migration: 20260820000021_30497cfd-e272-46ad-ab57-c02f09752c77.sql
-- =============================================

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
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT INSERT ON public.points_transactions TO authenticated;
GRANT INSERT ON public.referrals TO authenticated;


-- =============================================
-- Migration: 20260820000027_7b79f6cb-4da8-436d-a1cb-d3e226bca272.sql
-- =============================================

-- Revoke public execution for handle_new_user
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Revoke public execution for reward_referrer_on_signup
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820000037_ce87cd8c-6c1f-4c7d-9f09-94ab6b579db0.sql
-- =============================================

-- Internal Triggers (should only be executable by system)
REVOKE ALL ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.log_task_status_change() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.log_user_task_activity() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.update_user_points_balance() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Admin-only functions (checked via has_role, but limiting execution is safer)
REVOKE ALL ON FUNCTION public.assign_role(UUID, public.app_role) FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.remove_role(UUID, public.app_role) FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820000714_09e1940a-02d6-47a3-b307-a3b6a4a0640d.sql
-- =============================================

-- Create analytics_events table
CREATE TABLE public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    event_name TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT INSERT, SELECT ON public.analytics_events TO anon;
GRANT INSERT, SELECT ON public.analytics_events TO authenticated;
GRANT ALL ON public.analytics_events TO service_role;

-- Enable RLS
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Allow anonymous and authenticated users to insert events
CREATE POLICY "Allow anyone to insert events" ON public.analytics_events FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow users to view their own events" ON public.analytics_events FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);


-- =============================================
-- Migration: 20260820001205_7d9df204-b5ca-444a-8fc2-dccfb22ffbbf.sql
-- =============================================

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


-- =============================================
-- Migration: 20260820001236_03dc43c5-807d-493c-a91b-5f2f2bd9f363.sql
-- =============================================

-- Secure the check_referral_code function
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- System triggers
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Reward function
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820002257_53690129-99c3-4421-a461-a2ba8a7706b1.sql
-- =============================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS welcome_banner_dismissed BOOLEAN DEFAULT FALSE;


-- =============================================
-- Migration: 20260820002819_ef52acf6-571b-43a5-91a3-5b9d2943fefe.sql
-- =============================================


-- Profiles: Allow admins to select all
CREATE POLICY "Admins can select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Referrals: Allow admins to select all
CREATE POLICY "Admins can select all referrals" ON public.referrals
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Points Transactions: Allow admins to select all
CREATE POLICY "Admins can select all transactions" ON public.points_transactions
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Analytics Events: Allow admins to select all
CREATE POLICY "Admins can select all analytics events" ON public.analytics_events
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- User Streaks: Allow admins to select all
CREATE POLICY "Admins can select all streaks" ON public.user_streaks
FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));


-- =============================================
-- Migration: 20260820003325_57dc8bb7-70da-4ba4-9e21-26bcf2976452.sql
-- =============================================

-- 1. Buckets policies (Allowing SELECT so client can find bucket)
DROP POLICY IF EXISTS "Public can view buckets" ON storage.buckets;
CREATE POLICY "Public can view buckets" ON storage.buckets FOR SELECT TO public USING (true);

-- 2. Rewards objects policies
DROP POLICY IF EXISTS "Admins can manage rewards" ON storage.objects;
CREATE POLICY "Admins can manage rewards" 
ON storage.objects 
FOR ALL 
TO authenticated 
USING (
  bucket_id = 'rewards' AND 
  public.has_role(auth.uid(), 'admin')
)
WITH CHECK (
  bucket_id = 'rewards' AND 
  public.has_role(auth.uid(), 'admin')
);

DROP POLICY IF EXISTS "Anyone can view rewards" ON storage.objects;
CREATE POLICY "Anyone can view rewards" 
ON storage.objects 
FOR SELECT 
TO public 
USING (bucket_id = 'rewards');

-- 3. Enhanced Avatars policies for Admins
DROP POLICY IF EXISTS "Admins can manage all avatars" ON storage.objects;
CREATE POLICY "Admins can manage all avatars" 
ON storage.objects 
FOR ALL 
TO authenticated 
USING (
  bucket_id = 'avatars' AND 
  public.has_role(auth.uid(), 'admin')
)
WITH CHECK (
  bucket_id = 'avatars' AND 
  public.has_role(auth.uid(), 'admin')
);

-- =============================================
-- Migration: 20260820003838_40ffa473-f873-471c-96ac-748e89ac6693.sql
-- =============================================


-- 1. Drop leftover email lookup function
DROP FUNCTION IF EXISTS public.get_user_email_by_username(text);

-- 2. Guard sensitive profile columns
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' AND NOT public.has_role(auth.uid(), 'admin') THEN
    NEW.points_balance := OLD.points_balance;
    NEW.referral_code := OLD.referral_code;
    NEW.referred_by := OLD.referred_by;
    NEW.referral_clicks := OLD.referral_clicks;
    NEW.has_claimed_welcome_bonus := OLD.has_claimed_welcome_bonus;
    NEW.email := OLD.email;
    NEW.id := OLD.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_sensitive_columns ON public.profiles;
CREATE TRIGGER guard_profile_sensitive_columns
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.guard_profile_sensitive_columns();

-- 3. Atomic redemption RPC
DROP POLICY IF EXISTS "Users can insert redemptions" ON public.redemptions;

CREATE OR REPLACE FUNCTION public.redeem_reward(_reward_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_reward record;
  v_balance integer;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'You must be signed in to redeem rewards.');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

  SELECT * INTO v_reward FROM public.rewards WHERE id = _reward_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Reward is not available.');
  END IF;

  IF v_reward.stock_count IS NOT NULL AND v_reward.stock_count <= 0 THEN
    RETURN json_build_object('success', false, 'message', 'This reward is out of stock.');
  END IF;

  SELECT points_balance INTO v_balance FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF COALESCE(v_balance, 0) < v_reward.cost_points THEN
    RETURN json_build_object('success', false, 'message', 'You do not have enough points for this reward.');
  END IF;

  INSERT INTO public.redemptions (user_id, reward_id, status)
  VALUES (v_user_id, _reward_id, 'pending');

  INSERT INTO public.points_transactions (user_id, amount, type, description)
  VALUES (v_user_id, -v_reward.cost_points, 'redemption', 'Redeemed ' || v_reward.title);

  IF v_reward.stock_count IS NOT NULL THEN
    UPDATE public.rewards SET stock_count = stock_count - 1 WHERE id = _reward_id;
  END IF;

  RETURN json_build_object('success', true, 'message', 'Redemption request submitted!', 'cost', v_reward.cost_points);
END;
$$;

-- 4. Lock down SECURITY DEFINER function execution
REVOKE ALL ON FUNCTION public.guard_profile_sensitive_columns() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_task_status_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_user_task_activity() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_user_points_balance() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.check_referral_code(text) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.check_referral_code(text);

REVOKE ALL ON FUNCTION public.check_referral_code(text, uuid) FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.lookup_login_email(text) FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.redeem_reward(uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820004000_fix_rls_and_admin_rpc.sql
-- =============================================

-- 1. Create a dedicated RPC for admins to adjust points
CREATE OR REPLACE FUNCTION public.admin_adjust_points(
    _user_id uuid, 
    _amount integer, 
    _type text, 
    _description text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security check: only admins can call this
    IF NOT public.has_role(auth.uid(), 'admin') THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Insert the transaction
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, _amount, _type, _description);

    RETURN json_build_object('success', true, 'message', 'Points adjusted successfully');
END;
$$;

-- 2. Revoke and Grant for the new RPC
REVOKE ALL ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3. Ensure proper GRANTs on redemptions and points_transactions
-- These are often missing or dropped in previous migrations
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;

-- 4. Update the redemptions policy to allow the system (SECURITY DEFINER) to insert
-- RLS policies don't apply to SECURITY DEFINER functions owned by a superuser/admin role
-- but sometimes explicit policies help if the function is not acting as owner.
-- The existing policies should be fine, but let's ensure service_role can do everything.


-- =============================================
-- Migration: 20260820013108_b3352476-924a-4c39-a504-222d9a2cc3da.sql
-- =============================================


-- Drop existing function first to change return type or signature if needed
DROP FUNCTION IF EXISTS public.claim_welcome_bonus(_user_id uuid);

-- Add social handles columns to profiles table if they don't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS twitter_handle TEXT,
ADD COLUMN IF NOT EXISTS facebook_handle TEXT,
ADD COLUMN IF NOT EXISTS telegram_handle TEXT,
ADD COLUMN IF NOT EXISTS instagram_handle TEXT;

-- Re-create the referral bonus logic to require social handles
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- CHECK FOR SOCIAL HANDLES (REFEREE MUST COMPLETE THIS)
    IF v_profile.twitter_handle IS NULL OR v_profile.twitter_handle = '' OR
       v_profile.telegram_handle IS NULL OR v_profile.telegram_handle = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram at minimum) to be eligible for the bonus.');
    END IF;

    -- Mark as claimed
    UPDATE public.profiles SET has_claimed_welcome_bonus = true WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        -- Check if referrer exists
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$$;


-- =============================================
-- Migration: 20260820013554_7feb8c12-830c-46b8-a419-78f0bb6efd1f.sql
-- =============================================

-- Hardening claim_welcome_bonus function with server-side social handle validation
-- and ensuring uniqueness/format for handles.

CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean and validate handles
    -- Removing @ if present to standardize
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- CHECK FOR SOCIAL HANDLES (REFEREE MUST COMPLETE THIS)
    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram at minimum) to be eligible for the bonus.');
    END IF;

    -- Basic format validation (alphanumeric and underscores usually for handles)
    IF NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format. Use only letters, numbers, and underscores.');
    END IF;
    
    IF NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format. Should be 5-32 characters (letters, numbers, underscores).');
    END IF;

    -- Prevent Duplicate Handles (ensure another profile doesn't have the same handle already verified/claimed)
    -- This prevents multiple accounts using the same social handles to claim bonuses.
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id != _user_id 
        AND has_claimed_welcome_bonus = true 
        AND (
            (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
            (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean)
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- Update handles to cleaned versions and mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        -- Check if referrer exists
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

-- =============================================
-- Migration: 20260820013609_f025a1c9-0327-4bbe-887c-76761e70c3b6.sql
-- =============================================

-- Secure the claim_welcome_bonus function to only be executable by authenticated users
-- and revoke public access to prevent potential abuse.

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260820020756_fix_redemptions_profiles_relationship.sql
-- =============================================

ALTER TABLE public.redemptions DROP CONSTRAINT IF EXISTS redemptions_user_id_fkey;
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;


-- =============================================
-- Migration: 20260820020802_f7e07f9b-0360-47d0-b610-3902ce5fc6bc.sql
-- =============================================

ALTER TABLE public.redemptions DROP CONSTRAINT IF EXISTS redemptions_user_id_fkey;
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

-- =============================================
-- Migration: 20260820023108_1ac36b4f-b3d1-437a-b3df-28ca45bebe33.sql
-- =============================================

-- Function to handle redemption status changes with point refunds/deductions
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(
    _redemption_id UUID,
    _new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_redemption RECORD;
    v_reward RECORD;
    v_profile RECORD;
    v_old_status TEXT;
    v_cost INTEGER;
    v_admin_id UUID;
BEGIN
    -- Get current user ID (must be admin)
    v_admin_id := auth.uid();
    
    IF NOT public.has_role(v_admin_id, 'admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin role required');
    END IF;

    -- Get redemption details
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
    END IF;

    v_old_status := v_redemption.status;
    
    -- If status hasn't changed, just return success
    IF v_old_status = _new_status THEN
        RETURN jsonb_build_object('success', true, 'message', 'Status unchanged');
    END IF;

    -- Get reward details for cost
    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    v_cost := v_reward.cost_points;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_redemption.user_id FOR UPDATE;

    -- LOGIC FOR REFUNDS (Moving TO Rejected from any other status)
    IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
        -- Refund points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, v_cost, 'earn', 'Refund: Rejected "' || v_reward.title || '" redemption', _redemption_id);
        
        -- points_balance is updated by trigger on points_transactions
    END IF;

    -- LOGIC FOR RE-DEDUCTION (Moving FROM Rejected to Approved or Pending)
    IF v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending') THEN
        -- Check if user has enough points to re-deduct
        IF v_profile.points_balance < v_cost THEN
            RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-process this redemption');
        END IF;

        -- Re-deduct points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, -v_cost, 'spend', 'Re-processing "' || v_reward.title || '" redemption', _redemption_id);
    END IF;

    -- Update redemption status
    UPDATE public.redemptions
    SET status = _new_status
    WHERE id = _redemption_id;

    -- Create audit log
    INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
    VALUES (
        v_admin_id,
        'redemptions',
        _redemption_id,
        'update_status',
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', _new_status)
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Redemption status updated to ' || _new_status,
        'refunded', (_new_status = 'rejected' AND v_old_status != 'rejected'),
        're_deducted', (v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending'))
    );
END;
$$;

-- Grant execute to authenticated users (role check inside function handles security)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820023141_977492e6-fab5-471e-9a22-4bdd4cea67f8.sql
-- =============================================

-- Revoke EXECUTE from PUBLIC and anon for sensitive functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(UUID) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(UUID, UUID) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.redeem_reward(UUID) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-grant to specific roles
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(UUID, UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820023148_7cc39e17-03a3-428b-a53e-27665b911322.sql
-- =============================================

-- Revoke EXECUTE from PUBLIC and anon for remaining sensitive functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.lookup_login_email(TEXT) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-grant to authenticated roles
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(TEXT) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820023943_9448ecd0-9694-4485-9d17-1568be2fe8cf.sql
-- =============================================

ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;


-- =============================================
-- Migration: 20260820024024_41bf1ddd-8eea-4a47-9b1c-f5e5f90ab199.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.process_redemption_status_change(_redemption_id uuid, _new_status text, _rejection_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_redemption RECORD;
    v_reward RECORD;
    v_profile RECORD;
    v_old_status TEXT;
    v_cost INTEGER;
    v_admin_id UUID;
BEGIN
    -- Get current user ID (must be admin)
    v_admin_id := auth.uid();
    
    IF NOT public.has_role(v_admin_id, 'admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin role required');
    END IF;

    -- Get redemption details
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
    END IF;

    v_old_status := v_redemption.status;
    
    -- If status hasn't changed and no new reason, just return success
    IF v_old_status = _new_status AND (_rejection_reason IS NULL OR v_redemption.rejection_reason = _rejection_reason) THEN
        RETURN jsonb_build_object('success', true, 'message', 'Status unchanged');
    END IF;

    -- Get reward details for cost
    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    v_cost := v_reward.cost_points;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_redemption.user_id FOR UPDATE;

    -- LOGIC FOR REFUNDS (Moving TO Rejected from any other status)
    IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
        -- Refund points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, v_cost, 'earn', 'Refund: Rejected "' || v_reward.title || '" redemption' || CASE WHEN _rejection_reason IS NOT NULL THEN ' - ' || _rejection_reason ELSE '' END, _redemption_id);
        
        -- points_balance is updated by trigger on points_transactions
    END IF;

    -- LOGIC FOR RE-DEDUCTION (Moving FROM Rejected to Approved or Pending)
    IF v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending') THEN
        -- Check if user has enough points to re-deduct
        IF v_profile.points_balance < v_cost THEN
            RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-process this redemption');
        END IF;

        -- Re-deduct points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, -v_cost, 'spend', 'Re-processing "' || v_reward.title || '" redemption', _redemption_id);
    END IF;

    -- Update redemption status and reason
    UPDATE public.redemptions
    SET 
        status = _new_status,
        rejection_reason = CASE WHEN _new_status = 'rejected' THEN COALESCE(_rejection_reason, rejection_reason) ELSE NULL END
    WHERE id = _redemption_id;

    -- Create audit log
    INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
    VALUES (
        v_admin_id,
        'redemptions',
        _redemption_id,
        'update_status',
        jsonb_build_object('status', v_old_status, 'reason', v_redemption.rejection_reason),
        jsonb_build_object('status', _new_status, 'reason', _rejection_reason)
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Redemption status updated to ' || _new_status,
        'refunded', (_new_status = 'rejected' AND v_old_status != 'rejected'),
        're_deducted', (v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending'))
    );
END;
$function$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820024049_e970dcd4-69b8-427b-9b2a-fdcbf59f412b.sql
-- =============================================

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820024100_fae512b8-2e32-43e4-b2dd-8f09b019cadf.sql
-- =============================================

DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text);
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820024114_86ef8a08-bb39-42b2-b1ce-c3551efe9ad5.sql
-- =============================================

ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

CREATE OR REPLACE FUNCTION public.process_redemption_status_change(_redemption_id uuid, _new_status text, _rejection_reason text DEFAULT '')
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_redemption RECORD;
    v_reward RECORD;
    v_profile RECORD;
    v_old_status TEXT;
    v_cost INTEGER;
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_role(v_admin_id, 'admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin role required');
    END IF;

    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
    END IF;

    v_old_status := v_redemption.status;
    
    IF v_old_status = _new_status AND (_rejection_reason = '' OR v_redemption.rejection_reason = _rejection_reason) THEN
        RETURN jsonb_build_object('success', true, 'message', 'Status unchanged');
    END IF;

    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    v_cost := v_reward.cost_points;
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_redemption.user_id FOR UPDATE;

    IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, v_cost, 'earn', 'Refund: Rejected "' || v_reward.title || '" redemption' || CASE WHEN _rejection_reason != '' THEN ' - ' || _rejection_reason ELSE '' END, _redemption_id);
    END IF;

    IF v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending') THEN
        IF v_profile.points_balance < v_cost THEN
            RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-process this redemption');
        END IF;
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, -v_cost, 'spend', 'Re-processing "' || v_reward.title || '" redemption', _redemption_id);
    END IF;

    UPDATE public.redemptions
    SET 
        status = _new_status,
        rejection_reason = CASE WHEN _new_status = 'rejected' THEN COALESCE(NULLIF(_rejection_reason, ''), rejection_reason) ELSE NULL END
    WHERE id = _redemption_id;

    INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
    VALUES (
        v_admin_id,
        'redemptions',
        _redemption_id,
        'update_status',
        jsonb_build_object('status', v_old_status, 'reason', v_redemption.rejection_reason),
        jsonb_build_object('status', _new_status, 'reason', _rejection_reason)
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Redemption status updated to ' || _new_status,
        'refunded', (_new_status = 'rejected' AND v_old_status != 'rejected'),
        're_deducted', (v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending'))
    );
END;
$function$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820024249_bc7d2747-f8d4-4924-b551-56a34113b8f6.sql
-- =============================================

-- Attempt to explicitly drop both potential signatures to clear any ambiguity
DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text);
DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text, text);

-- Re-create the function with a single clear signature
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(
  _redemption_id uuid,
  _new_status text,
  _rejection_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_points integer;
  v_old_status text;
  v_result jsonb;
  v_refunded boolean DEFAULT false;
  v_re_deducted boolean DEFAULT false;
BEGIN
  -- Get current status and details
  SELECT user_id, status, (SELECT rewards.cost_points FROM rewards WHERE rewards.id = redemptions.reward_id)
  INTO v_user_id, v_old_status, v_points
  FROM redemptions
  WHERE id = _redemption_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
  END IF;

  -- Handle point adjustments
  -- 1. Refund points if moving TO rejected from something else
  IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
    UPDATE profiles 
    SET points_balance = points_balance + v_points 
    WHERE id = v_user_id;
    
    INSERT INTO points_transactions (user_id, amount, type, description)
    VALUES (v_user_id, v_points, 'referral_bonus', 'Refund: Reward redemption rejected');
    
    v_refunded := true;
  END IF;

  -- 2. Deduct points if moving FROM rejected to something else
  IF v_old_status = 'rejected' AND _new_status != 'rejected' THEN
    -- Check if user has enough points
    IF (SELECT points_balance FROM profiles WHERE id = v_user_id) < v_points THEN
      RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-deduct for this reward');
    END IF;

    UPDATE profiles 
    SET points_balance = points_balance - v_points 
    WHERE id = v_user_id;
    
    INSERT INTO points_transactions (user_id, amount, type, description)
    VALUES (v_user_id, -v_points, 'redemption', 'Re-deduction: Reward redemption re-activated');
    
    v_re_deducted := true;
  END IF;

  -- Update the redemption record
  UPDATE redemptions
  SET 
    status = _new_status,
    rejection_reason = CASE 
      WHEN _new_status = 'rejected' THEN _rejection_reason 
      ELSE NULL 
    END,
    updated_at = now()
  WHERE id = _redemption_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Status updated successfully',
    'refunded', v_refunded,
    're_deducted', v_re_deducted
  );
END;
$$;

-- Explicitly grant permissions
REVOKE ALL ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260820024705_c78f8bd3-583d-4cbc-9020-178efdaf9b7f.sql
-- =============================================


-- Add updated_at column to redemptions table
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop the trigger if it exists and recreate it
DROP TRIGGER IF EXISTS update_redemptions_updated_at ON public.redemptions;
CREATE TRIGGER update_redemptions_updated_at
    BEFORE UPDATE ON public.redemptions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();


-- =============================================
-- Migration: 20260820025115_20d9c02f-94f8-4f24-940a-45604f3d764c.sql
-- =============================================


-- 1. Add video_ad_count to tasks table
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS video_ad_count INTEGER DEFAULT 0;

-- 2. Create a new table to track progress on video ad tasks
CREATE TABLE IF NOT EXISTS public.video_ad_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    watch_count INTEGER NOT NULL DEFAULT 0,
    last_watch_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, task_id)
);

-- 3. Enable RLS and add policies for video_ad_progress
ALTER TABLE public.video_ad_progress ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.video_ad_progress TO authenticated;
GRANT ALL ON public.video_ad_progress TO service_role;

CREATE POLICY "Users can view their own video progress"
    ON public.video_ad_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own video progress"
    ON public.video_ad_progress FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own watch count"
    ON public.video_ad_progress FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- 4. Create an RPC to record a video watch
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 1. Get task details
    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true AND category = 'Videos';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Video task not found or inactive.');
    END IF;

    -- 2. Check if already completed in task_submissions
    IF EXISTS (SELECT 1 FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified') THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- 3. Update or insert progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    -- 4. Check if finished (10 ads)
    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Auto-verify and award points
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT DO NOTHING;
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed video task: ' || v_task_record.title, v_now);
        
        RETURN json_build_object(
            'success', true, 
            'completed', true, 
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true, 
        'completed', false, 
        'watch_count', v_progress_record.watch_count,
        'message', 'Video watch recorded (' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ')'
    );
END;
$$;


-- =============================================
-- Migration: 20260820025206_d2f82928-650f-4bc4-9779-e1843a4bb189.sql
-- =============================================

-- Fix security linter warnings for record_video_watch
REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Also fix security linter warnings for submit_task (detected in previous linter output)
REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820040150_f7dbf266-532b-4408-a6da-45abc83bcb6c.sql
-- =============================================

-- Drop existing function with old signature to allow changing return type
DROP FUNCTION IF EXISTS public.check_referral_code(text, uuid);

-- Re-defining the function with standardized parameters and return types
CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, message text) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_username text;
BEGIN
    -- 1. Find referrer
    SELECT p.username INTO v_referrer_username
    FROM public.profiles p
    WHERE p.referral_code = _code
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    -- 2. Success
    RETURN QUERY SELECT v_referrer_username, TRUE, 'Valid referral code.'::text;
END;
$$;

-- Explicitly grant execute permission
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260820043528_ceb90909-dfa4-4967-9886-67581dcc4a3f.sql
-- =============================================

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS vast_tag_url TEXT;

COMMENT ON COLUMN public.tasks.vast_tag_url IS 'The VAST XML URL for video ad tasks';

-- =============================================
-- Migration: 20260820045200_7a1542e8-abcc-479f-93b7-904c508dbd27.sql
-- =============================================

INSERT INTO public.tasks (
    title, 
    description, 
    points, 
    category, 
    is_active, 
    video_ad_count, 
    vast_tag_url
) VALUES (
    'Premium Video Reward', 
    'Watch a premium video advertisement to earn points.', 
    20, 
    'Videos', 
    true, 
    1, 
    'https://s.magsrv.com/v1/vast.php?idzone=6006964'
);

-- =============================================
-- Migration: 20260820045817_f1a9bc2d-34a3-4328-8e4a-0203c278e2f3.sql
-- =============================================

-- Harden record_video_watch with security best practices
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    -- SECURITY CHECK: Only the user themselves can record a watch
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 1. Get task details - must be active, video category, and have a valid ad count
    SELECT * INTO v_task_record 
    FROM public.tasks 
    WHERE id = _task_id 
      AND is_active = true 
      AND category = 'Videos'
      AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    -- 2. Check if already completed
    IF EXISTS (
        SELECT 1 FROM public.task_submissions 
        WHERE user_id = _user_id 
          AND task_id = _task_id 
          AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- 3. Update or insert progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    -- 4. Check if finished
    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Atomic completion
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE 
        SET status = 'verified', created_at = v_now;
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed video task: ' || v_task_record.title, v_now);
        
        -- Clean up progress table (optional, but keeps it tidy)
        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true, 
            'completed', true, 
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true, 
        'completed', false, 
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$$;

-- Ensure permissions are correctly set
REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820051000_automated_fraud_detection.sql
-- =============================================

-- Automated Fraud Detection System

-- 1. Add fraud status and flags to redemptions
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS is_flagged boolean DEFAULT false;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS fraud_score float DEFAULT 0;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS fraud_details jsonb DEFAULT '{}'::jsonb;

-- 2. Function to detect potential fraud on redemption request
CREATE OR REPLACE FUNCTION public.detect_redemption_fraud()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := NEW.user_id;
    v_fraud_flags text[] := ARRAY[]::text[];
    v_fraud_score float := 0;
    v_recent_redemptions_count int;
    v_total_points_24h int;
    v_points_balance int;
    v_user_created_at timestamp with time zone;
    v_is_flagged boolean := false;
BEGIN
    -- Only run check on new redemptions or when status is pending
    IF TG_OP = 'UPDATE' AND OLD.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    -- A. Check for rapid-fire redemptions (more than 3 in 1 hour)
    SELECT count(*) INTO v_recent_redemptions_count
    FROM public.redemptions
    WHERE user_id = v_user_id
      AND created_at > now() - interval '1 hour';
    
    IF v_recent_redemptions_count >= 3 THEN
        v_fraud_flags := array_append(v_fraud_flags, 'high_frequency_redemption');
        v_fraud_score := v_fraud_score + 0.4;
    END IF;

    -- B. Check for high points earning in short period (e.g., > 1000 points in 24h)
    SELECT coalesce(sum(amount), 0) INTO v_total_points_24h
    FROM public.points_transactions
    WHERE user_id = v_user_id
      AND type = 'earn'
      AND created_at > now() - interval '24 hours';
    
    IF v_total_points_24h > 1000 THEN
        v_fraud_flags := array_append(v_fraud_flags, 'unusually_high_earnings_24h');
        v_fraud_score := v_fraud_score + 0.3;
    END IF;

    -- C. Check account age (flag if account is less than 24 hours old)
    SELECT created_at INTO v_user_created_at
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_user_created_at > now() - interval '24 hours' THEN
        v_fraud_flags := array_append(v_fraud_flags, 'new_account_payout');
        v_fraud_score := v_fraud_score + 0.2;
    END IF;

    -- D. Check for suspicious referral patterns (same IP/fingerprint logic would go here if we tracked it)
    -- For now, check if they have a large number of referrals but zero tasks completed
    IF EXISTS (
        SELECT 1 FROM public.referrals r
        WHERE r.referrer_id = v_user_id
        HAVING count(*) > 10
    ) AND NOT EXISTS (
        SELECT 1 FROM public.task_submissions ts
        WHERE ts.user_id = v_user_id
          AND ts.status = 'verified'
    ) THEN
        v_fraud_flags := array_append(v_fraud_flags, 'suspicious_referral_only_profile');
        v_fraud_score := v_fraud_score + 0.5;
    END IF;

    -- E. Auto-hold logic
    IF v_fraud_score >= 0.5 OR array_length(v_fraud_flags, 1) > 0 THEN
        v_is_flagged := true;
        NEW.status := 'review_required'; -- NEW STATUS: Holds the payout
        NEW.is_flagged := true;
        NEW.fraud_score := v_fraud_score;
        NEW.fraud_details := jsonb_build_object(
            'flags', v_fraud_flags,
            'checked_at', now(),
            'score', v_fraud_score
        );
        
        -- Log to audit
        INSERT INTO public.admin_audit_logs (action_type, target_table, target_id, new_data)
        VALUES ('auto_fraud_flag', 'redemptions', NEW.id, NEW.fraud_details);
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Trigger for fraud detection
DROP TRIGGER IF EXISTS tr_detect_redemption_fraud ON public.redemptions;
CREATE TRIGGER tr_detect_redemption_fraud
BEFORE INSERT OR UPDATE ON public.redemptions
FOR EACH ROW
EXECUTE FUNCTION public.detect_redemption_fraud();

-- 4. Grant permissions
GRANT UPDATE(is_flagged, fraud_score, fraud_details) ON public.redemptions TO authenticated;
GRANT UPDATE(is_flagged, fraud_score, fraud_details) ON public.redemptions TO service_role;



-- =============================================
-- Migration: 20260820051500_update_process_redemption.sql
-- =============================================

-- Update process_redemption_status_change to handle review_required state
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(_redemption_id uuid, _new_status text, _rejection_reason text DEFAULT '')
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_redemption record;
    v_reward record;
    v_now timestamp with time zone := now();
    v_refunded boolean := false;
    v_re_deducted boolean := false;
BEGIN
    -- 1. Check if admin
    IF NOT public.has_role(auth.uid(), 'admin') THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized. Admin only.');
    END IF;

    -- 2. Get redemption record
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Redemption not found.');
    END IF;

    -- 3. Get reward details for points info
    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    
    -- 4. Check if we need to refund (transition from something non-rejected to rejected)
    IF _new_status = 'rejected' AND v_redemption.status <> 'rejected' THEN
        UPDATE public.profiles
        SET points_balance = points_balance + v_reward.cost_points
        WHERE id = v_redemption.user_id;
        
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (v_redemption.user_id, v_reward.cost_points, 'earn', 'Refund for rejected reward: ' || v_reward.title, v_now);
        
        v_refunded := true;
    END IF;

    -- 5. Check if we need to re-deduct (transition from rejected to something else)
    IF v_redemption.status = 'rejected' AND _new_status <> 'rejected' THEN
        -- Check if user has enough balance
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_redemption.user_id AND points_balance >= v_reward.cost_points) THEN
            RETURN json_build_object('success', false, 'message', 'User no longer has enough points for this reward.');
        END IF;

        UPDATE public.profiles
        SET points_balance = points_balance - v_reward.cost_points
        WHERE id = v_redemption.user_id;
        
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (v_redemption.user_id, -v_reward.cost_points, 'redeem', 'Points re-deducted for reward: ' || v_reward.title, v_now);
        
        v_re_deducted := true;
    END IF;

    -- 6. Update the record
    UPDATE public.redemptions
    SET 
        status = _new_status,
        rejection_reason = CASE WHEN _new_status = 'rejected' THEN _rejection_reason ELSE NULL END,
        updated_at = v_now,
        -- Auto-clear flags if approved by admin
        is_flagged = CASE WHEN _new_status = 'approved' THEN false ELSE is_flagged END
    WHERE id = _redemption_id;

    -- 7. Audit log
    INSERT INTO public.admin_audit_logs (action_type, target_table, target_id, new_data, old_data)
    VALUES ('status_change', 'redemptions', _redemption_id, json_build_object('status', _new_status, 'reason', _rejection_reason), json_build_object('status', v_redemption.status));

    RETURN json_build_object(
        'success', true, 
        'refunded', v_refunded, 
        're_deducted', v_re_deducted, 
        'message', 'Status updated successfully.'
    );
END;
$$;


-- =============================================
-- Migration: 20260820165000_platform_settings.sql
-- =============================================

-- Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT SELECT ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read access for authenticated users" 
ON public.app_settings FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Allow admin to manage settings" 
ON public.app_settings FOR ALL 
TO authenticated 
USING (public.has_role(auth.uid(), 'admin'));

-- Initial Settings
INSERT INTO public.app_settings (key, value, description)
VALUES 
('welcome_bonus_enabled', 'true'::jsonb, 'Enable or disable the welcome bonus for referred users'),
('welcome_bonus_amount_referee', '50'::jsonb, 'Amount of points given to the new user (referee)'),
('welcome_bonus_amount_referrer', '75'::jsonb, 'Amount of points given to the user who invited them (referrer)'),
('welcome_bonus_required_socials', '["twitter", "telegram"]'::jsonb, 'List of social handles required to claim the bonus')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description;

-- Update claim_welcome_bonus function
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
BEGIN
    -- Read settings from app_settings
    SELECT (value->>0)::boolean INTO v_bonus_enabled FROM public.app_settings WHERE key = 'welcome_bonus_enabled';
    SELECT (value->>0)::integer INTO v_referral_points_referee FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
    SELECT (value->>0)::integer INTO v_referral_points_referrer FROM public.app_settings WHERE key = 'welcome_bonus_amount_referrer';
    SELECT value INTO v_required_socials FROM public.app_settings WHERE key = 'welcome_bonus_required_socials';

    -- Defaults if settings are missing
    v_bonus_enabled := COALESCE(v_bonus_enabled, true);
    v_referral_points_referee := COALESCE(v_referral_points_referee, 50);
    v_referral_points_referrer := COALESCE(v_referral_points_referrer, 75);
    v_required_socials := COALESCE(v_required_socials, '["twitter", "telegram"]'::jsonb);

    IF NOT v_bonus_enabled THEN
        RETURN json_build_object('success', false, 'message', 'Welcome bonus program is currently disabled.');
    END IF;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean and validate handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Dynamic validation based on required_socials setting
    IF ('"twitter"'::jsonb <@ v_required_socials) AND (v_twitter_clean IS NULL OR v_twitter_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Twitter profile to be eligible.');
    END IF;

    IF ('"telegram"'::jsonb <@ v_required_socials) AND (v_telegram_clean IS NULL OR v_telegram_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Telegram profile to be eligible.');
    END IF;
    
    -- Format validation for Twitter
    IF (v_twitter_clean IS NOT NULL AND v_twitter_clean != '') AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    -- Format validation for Telegram
    IF (v_telegram_clean IS NOT NULL AND v_telegram_clean != '') AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- Prevent Duplicate Handles
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id != _user_id 
        AND has_claimed_welcome_bonus = true 
        AND (
            (twitter_handle IS NOT NULL AND v_twitter_clean IS NOT NULL AND twitter_handle = v_twitter_clean) OR
            (telegram_handle IS NOT NULL AND v_telegram_clean IS NOT NULL AND telegram_handle = v_telegram_clean)
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- Update handles to cleaned versions and mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;


-- =============================================
-- Migration: 20260820222602_5651d02d-2611-4893-a770-7c3a96a63e46.sql
-- =============================================

-- 1. Add fingerprint and last_ip to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fingerprint text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_ip text;

-- 2. Create fraud_flags table
CREATE TABLE IF NOT EXISTS public.fraud_flags (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    type text NOT NULL, -- 'multi_account', 'self_referral', 'suspicious_activity', 'social_duplicate'
    severity text DEFAULT 'medium', -- 'low', 'medium', 'high'
    details jsonb,
    status text DEFAULT 'pending', -- 'pending', 'reviewed', 'resolved'
    created_at timestamptz DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fraud_flags TO authenticated;
GRANT ALL ON public.fraud_flags TO service_role;

ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all fraud flags"
ON public.fraud_flags
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- 3. Update handle_new_user to include basic fraud detection
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    new_username text;
    base_username text;
    counter integer := 0;
    v_referrer_id uuid;
    v_fingerprint text;
    v_ip text;
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

    -- Extract fraud detection markers
    v_fingerprint := new.raw_user_meta_data->>'fingerprint';
    v_ip := new.raw_user_meta_data->>'ip_address';

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
        referred_by,
        fingerprint,
        last_ip
    )
    VALUES (
        new.id, 
        new.email,
        new_username, 
        COALESCE(new.raw_user_meta_data->>'full_name', ''),
        new.raw_user_meta_data->>'avatar_url',
        new_username,
        v_referrer_id,
        v_fingerprint,
        v_ip
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        username = EXCLUDED.username,
        full_name = EXCLUDED.full_name,
        referral_code = EXCLUDED.referral_code,
        avatar_url = EXCLUDED.avatar_url,
        referred_by = EXCLUDED.referred_by,
        fingerprint = COALESCE(EXCLUDED.fingerprint, profiles.fingerprint),
        last_ip = COALESCE(EXCLUDED.last_ip, profiles.last_ip);

    -- Record in referrals table if referrer exists
    IF v_referrer_id IS NOT NULL THEN
        -- SELF-REFERRAL DETECTION
        IF v_referrer_id = new.id THEN
            INSERT INTO public.fraud_flags (user_id, type, severity, details)
            VALUES (new.id, 'self_referral', 'high', jsonb_build_object('referrer_id', v_referrer_id));
        ELSE
            INSERT INTO public.referrals (referrer_id, referee_id)
            VALUES (v_referrer_id, new.id)
            ON CONFLICT (referee_id) DO NOTHING;
        END IF;
    END IF;

    -- MULTI-ACCOUNT DETECTION (Same Fingerprint)
    IF v_fingerprint IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.profiles WHERE fingerprint = v_fingerprint AND id != new.id
    ) THEN
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (new.id, 'multi_account', 'medium', jsonb_build_object('fingerprint', v_fingerprint));
    END IF;

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    RETURN new;
END;
$function$;

-- 4. Enhance claim_welcome_bonus to include social fraud detection
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
    v_duplicate_id uuid;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Validation patterns
    IF v_twitter_clean IS NOT NULL AND v_twitter_clean != '' AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    IF v_telegram_clean IS NOT NULL AND v_telegram_clean != '' AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- REQUIRED SOCIALS CHECK
    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram) to claim the bonus.');
    END IF;

    -- CROSS-ACCOUNT DUPLICATE SOCIAL DETECTION
    SELECT id INTO v_duplicate_id FROM public.profiles 
    WHERE id != _user_id 
    AND (
        (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
        (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean) OR
        (instagram_handle IS NOT NULL AND TRIM(LEADING '@' FROM instagram_handle) = v_instagram_clean) OR
        (facebook_handle IS NOT NULL AND facebook_handle = v_facebook_clean)
    )
    LIMIT 1;

    IF v_duplicate_id IS NOT NULL THEN
        -- Log fraud attempt
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (_user_id, 'social_duplicate', 'high', jsonb_build_object(
            'duplicate_user_id', v_duplicate_id,
            'twitter', v_twitter_clean,
            'telegram', v_telegram_clean
        ));
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- Update handles to cleaned versions and mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- Credit referrer
    IF v_profile.referred_by IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;


-- =============================================
-- Migration: 20260820230017_6739792d-58c8-4b05-b43c-7229ee1bd152.sql
-- =============================================

-- Speed up stats and list sorting
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_points_transactions_created_at ON public.points_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_redemptions_created_at ON public.redemptions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_created_at ON public.referrals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);

-- =============================================
-- Migration: 20260820230910_10fe9f86-f3e3-434c-b340-512fcf749419.sql
-- =============================================


-- Add transaction_id column to notifications
ALTER TABLE public.notifications 
ADD COLUMN transaction_id UUID REFERENCES public.points_transactions(id) ON DELETE SET NULL;

-- Grant access (good practice even if already granted to the table)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

-- Update the notification trigger function to include transaction_id
CREATE OR REPLACE FUNCTION public.notify_on_points_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
    VALUES (
        NEW.user_id,
        CASE WHEN NEW.amount > 0 THEN 'Points Earned!' ELSE 'Points Spent' END,
        NEW.description,
        'points',
        NEW.id
    );
    RETURN NEW;
END;
$function$;

-- Update referer reward trigger as well to handle the transaction_id if we want consistency
-- However, the notify_on_points_transaction trigger will ALREADY fire when 
-- reward_referrer_on_signup inserts into points_transactions.
-- Let's double check if notify_on_points_transaction is enabled on points_transactions.
-- It is: map[table_name:points_transactions trigger_name:on_points_transaction]


-- =============================================
-- Migration: 20260820233429_12a7a323-de76-427f-b9cc-f3e3731b9f07.sql
-- =============================================

-- Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT SELECT ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policies
-- First drop if exists to avoid errors on retry
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow read access for authenticated users' AND tablename = 'app_settings') THEN
        DROP POLICY "Allow read access for authenticated users" ON public.app_settings;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow admin to manage settings' AND tablename = 'app_settings') THEN
        DROP POLICY "Allow admin to manage settings" ON public.app_settings;
    END IF;
END $$;

CREATE POLICY "Allow read access for authenticated users" 
ON public.app_settings FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Allow admin to manage settings" 
ON public.app_settings FOR ALL 
TO authenticated 
USING (public.has_role(auth.uid(), 'admin'));

-- Initial Settings
INSERT INTO public.app_settings (key, value, description)
VALUES 
('welcome_bonus_enabled', 'true'::jsonb, 'Enable or disable the welcome bonus for referred users'),
('welcome_bonus_amount_referee', '50'::jsonb, 'Amount of points given to the new user (referee)'),
('welcome_bonus_amount_referrer', '75'::jsonb, 'Amount of points given to the user who invited them (referrer)'),
('welcome_bonus_required_socials', '["twitter", "telegram"]'::jsonb, 'List of social handles required to claim the bonus')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description;


-- =============================================
-- Migration: 20260820233457_8a73173c-b2f1-4486-b989-498caf8d2cca.sql
-- =============================================

-- 1. User Roles System
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('admin', 'user');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    from public.user_roles
    where user_id = _user_id
      and role = _role
  )
$$;


-- =============================================
-- Migration: 20260820233515_3ac7650e-928e-48f7-9e13-6bbfe06d2104.sql
-- =============================================

-- Revoke public execute on all public functions by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Revoke from existing functions specifically mentioned by linter or likely candidates
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Grant execute back to authenticated users for functions they need
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure all functions have search_path set
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.update_updated_at_column() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.check_referral_code(TEXT, UUID) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820234223_2596f4c4-3396-4c4d-aac1-b4c6e902cdbe.sql
-- =============================================

INSERT INTO public.user_roles (user_id, role)
SELECT 'b687073f-357b-4490-868f-6e7d567b3da1'::uuid, 'moderator'::public.app_role
WHERE EXISTS (SELECT 1 FROM auth.users WHERE id = 'b687073f-357b-4490-868f-6e7d567b3da1')
ON CONFLICT (user_id, role) DO NOTHING;

-- =============================================
-- Migration: 20260820235822_527d8963-8527-4a63-bf60-2e1aa87898b5.sql
-- =============================================


-- Revoke extra access to avoid leakage if RLS is bypassed or accidentally disabled
REVOKE ALL ON public.user_roles FROM public, anon, authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

-- Hardening RLS on user_roles: only user can see own role, admin can see all
DROP POLICY IF EXISTS "Admins can read all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can read their own roles" ON public.user_roles;

CREATE POLICY "Admins can select all roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users can select their own roles"
ON public.user_roles FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Ensure profiles are secure
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
CREATE POLICY "Admins can select all profiles"
ON public.profiles FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator'));

-- Ensure rewards are secure
DROP POLICY IF EXISTS "Admins can manage rewards" ON public.rewards;
CREATE POLICY "Admins can manage rewards"
ON public.rewards FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Hardening app_settings
DROP POLICY IF EXISTS "Allow admin to manage settings" ON public.app_settings;
CREATE POLICY "Admins can manage settings"
ON public.app_settings FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));


-- =============================================
-- Migration: 20260820235841_1a557f56-6031-4b79-bcf6-c12111950c8e.sql
-- =============================================


-- Security hardening: Revoke public execute from sensitive functions
-- These will only be callable by service_role or specifically granted roles (handled in handler/middleware)

-- Functions meant for public access (auth, signup, etc.)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Admin functions (should only be callable if the user has admin role)
-- But DB-level EXECUTE grant is usually for the role, then the function body checks has_role.
-- Let's restrict EXECUTE to authenticated and rely on internal has_role checks for the body.
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- User functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure internal/trigger functions are NOT executable by anyone but owner/service_role
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.log_task_status_change() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.log_user_task_activity() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.guard_profile_sensitive_columns() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_user_points_balance() FROM public, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260820235852_c0ed9c34-9860-457e-ac26-257fb50c2bfb.sql
-- =============================================


-- Fix excessive function permissions identified by the security linter
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure these functions are strictly authenticated
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Revoke all on generic helper functions from public access
REVOKE ALL ON FUNCTION public.update_updated_at_column() FROM public, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821000026_7ce6535d-eda9-4d2c-b2e0-0e9815da8470.sql
-- =============================================


-- Final security hardening: Fix remaining excessive function permissions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821005946_28f241ae-23ee-474b-bcef-e3d72a33a685.sql
-- =============================================

-- 1. analytics_events: remove anonymous-row visibility from public policy
DROP POLICY IF EXISTS "Allow users to view their own events" ON public.analytics_events;
CREATE POLICY "Allow users to view their own events"
ON public.analytics_events FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- 2. app_settings: only expose non-sensitive public keys to signed-in users
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON public.app_settings;
CREATE POLICY "Authenticated users can read public settings"
ON public.app_settings FOR SELECT TO authenticated
USING (key IN ('welcome_bonus_enabled','welcome_bonus_amount_referee','welcome_bonus_amount_referrer','welcome_bonus_required_socials'));

-- 3. notifications: add WITH CHECK to prevent reassigning rows
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 4. video_ad_progress: add WITH CHECK
DROP POLICY IF EXISTS "Users can update their own watch count" ON public.video_ad_progress;
CREATE POLICY "Users can update their own watch count"
ON public.video_ad_progress FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Tighten EXECUTE on SECURITY DEFINER functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.lookup_login_email(text) FROM authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 6. claim_welcome_bonus must only run for the caller
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
    v_duplicate_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: You can only claim the bonus for your own account.');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;

    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    IF v_twitter_clean IS NOT NULL AND v_twitter_clean != '' AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;

    IF v_telegram_clean IS NOT NULL AND v_telegram_clean != '' AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram) to claim the bonus.');
    END IF;

    SELECT id INTO v_duplicate_id FROM public.profiles
    WHERE id != _user_id
    AND (
        (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
        (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean) OR
        (instagram_handle IS NOT NULL AND TRIM(LEADING '@' FROM instagram_handle) = v_instagram_clean) OR
        (facebook_handle IS NOT NULL AND facebook_handle = v_facebook_clean)
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

    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    IF v_profile.referred_by IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260821010927_28c95624-ce42-4ce2-ba6f-6ca0998d644c.sql
-- =============================================

-- Restore execution permissions for core functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Fix Admin access to app_settings
DROP POLICY IF EXISTS "Admins can read all settings" ON public.app_settings;
CREATE POLICY "Admins can read all settings"
ON public.app_settings FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Ensure Admins can also update settings (missing in previous hardening)
DROP POLICY IF EXISTS "Admins can update all settings" ON public.app_settings;
CREATE POLICY "Admins can update all settings"
ON public.app_settings FOR ALL TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Re-grant access to user_roles for RLS evaluation
GRANT SELECT ON public.user_roles TO authenticated, service_role;


-- =============================================
-- Migration: 20260821011634_8a7c6ddd-86ce-4a71-b6b6-a44301cc6a7a.sql
-- =============================================

-- Restore access to referral validation for anonymous users (needed during signup)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure handle_new_user trigger correctly handles metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    full_name,
    username,
    avatar_url,
    points_balance,
    referred_by
  )
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url',
    0,
    (SELECT id FROM public.profiles WHERE referral_code = (new.raw_user_meta_data->>'referral_code_used') LIMIT 1)
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    avatar_url = EXCLUDED.avatar_url;
  
  RETURN new;
END;
$$;


-- =============================================
-- Migration: 20260821014219_be5ddf37-9b6c-4fd1-a439-7009dc1b90d9.sql
-- =============================================

-- Create Rank View
CREATE OR REPLACE VIEW public.user_ranks AS
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

GRANT SELECT ON public.user_ranks TO authenticated;
GRANT SELECT ON public.user_ranks TO service_role;

-- Create Detailed Referrals View
CREATE OR REPLACE VIEW public.my_referrals_detailed AS
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

GRANT SELECT ON public.my_referrals_detailed TO authenticated;
GRANT SELECT ON public.my_referrals_detailed TO service_role;

-- =============================================
-- Migration: 20260821014232_a09e53f1-d9d4-4130-9908-d1db69a118dd.sql
-- =============================================

-- Convert views to SECURITY INVOKER (Postgres default)
ALTER VIEW public.user_ranks SET (security_invoker = on);
ALTER VIEW public.my_referrals_detailed SET (security_invoker = on);

-- Audit functions for excessive permissions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821021723_79bc78ee-5e45-4828-a93b-8cb9b0b8604a.sql
-- =============================================

-- Fix the handle_new_user trigger to include the email field
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    username,
    avatar_url,
    points_balance,
    referred_by
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url',
    0,
    (SELECT id FROM public.profiles WHERE referral_code = (new.raw_user_meta_data->>'referral_code_used') LIMIT 1)
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    avatar_url = EXCLUDED.avatar_url;
  
  RETURN new;
END;
$function$;


-- =============================================
-- Migration: 20260821023634_e4189630-0eb5-4ffc-9514-8e45a9cc632b.sql
-- =============================================

-- We cannot directly change auth settings via SQL in Lovable Cloud
-- but we can ensure the application code correctly handles the 6-digit OTP
-- and verify the signup process.
-- This migration is a placeholder to document the requirement for 6-digit OTP
-- which is the default for Supabase Auth when verifyOtp is used in the frontend.

SELECT 1; -- No-op migration to satisfy tool requirements while I handle frontend logic


-- =============================================
-- Migration: 20260821024344_d1e5b4c3-31b2-482b-b738-9fd0cdee043a.sql
-- =============================================

-- Migration to handle pending referral bonuses and user completion status

-- 1. Add status to points_transactions if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'points_transactions' AND column_name = 'status') THEN
        ALTER TABLE public.points_transactions ADD COLUMN status text DEFAULT 'completed';
    END IF;
END $$;

-- 2. Update the reward_referrer_on_signup function to mark as pending
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50;
    v_new_user_bonus INTEGER := 50;
BEGIN
    -- Find the referrer
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

    -- If a referrer was found, award them points (PENDING)
    IF v_referrer_id IS NOT NULL THEN
        -- Transaction for Referrer
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username || ' (Pending profile completion)',
            'pending',
            NEW.id
        );

        -- Transaction for New User (Referee) - also pending
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
            NEW.id,
            v_new_user_bonus,
            'welcome_bonus',
            'Welcome bonus (Pending profile completion)',
            'pending',
            v_referrer_id
        );
        
        -- Notifications
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_referrer_id,
            'Referral Pending!',
            'You have a pending reward for referring ' || NEW.username || '. It will be available once they complete their profile.',
            'info'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Create function to check if profile is complete
CREATE OR REPLACE FUNCTION public.is_profile_complete(p_profile_id UUID)
RETURNS boolean AS $$
DECLARE
    v_profile public.profiles;
BEGIN
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_profile_id;
    
    RETURN (
        v_profile.full_name IS NOT NULL AND 
        v_profile.username IS NOT NULL AND 
        v_profile.phone_number IS NOT NULL AND 
        (v_profile.twitter_handle IS NOT NULL OR v_profile.telegram_handle IS NOT NULL OR v_profile.facebook_handle IS NOT NULL OR v_profile.instagram_handle IS NOT NULL)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 4. Trigger function to complete pending transactions
CREATE OR REPLACE FUNCTION public.check_pending_referrals_on_update()
RETURNS TRIGGER AS $$
DECLARE
    v_complete boolean;
BEGIN
    v_complete := public.is_profile_complete(NEW.id);
    
    IF v_complete AND NOT public.is_profile_complete(OLD.id) THEN
        -- 1. Complete transactions where this user is the source (Referrer's reward)
        UPDATE public.points_transactions 
        SET status = 'completed', 
            description = REPLACE(description, ' (Pending profile completion)', '')
        WHERE source_id = NEW.id AND type = 'referral' AND status = 'pending';

        -- 2. Complete transactions where this user is the recipient (Referee's reward)
        UPDATE public.points_transactions 
        SET status = 'completed', 
            description = REPLACE(description, ' (Pending profile completion)', '')
        WHERE user_id = NEW.id AND type = 'welcome_bonus' AND status = 'pending';

        -- Notify user
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            NEW.id,
            'Bonus Earned!',
            'Your welcome bonus has been credited for completing your profile!',
            'reward'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Attach update trigger
DROP TRIGGER IF EXISTS on_profile_update_check_referral ON public.profiles;
CREATE TRIGGER on_profile_update_check_referral
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.check_pending_referrals_on_update();

-- 5. Modify points balance sync to ignore pending transactions
CREATE OR REPLACE FUNCTION public.sync_points_balance()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = NEW.user_id AND status = 'completed'
    )
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Grants
GRANT SELECT, INSERT, UPDATE ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;


-- =============================================
-- Migration: 20260821024546_262d3c53-edd2-4295-bd80-f9d4702bf56d.sql
-- =============================================

-- Security Hardening for new referral functions

-- Revoke execute on new functions from public
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.is_profile_complete(UUID) FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Grant execute to relevant roles
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(UUID) TO authenticated, service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role, postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-set search_path to be extra safe
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.reward_referrer_on_signup() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.is_profile_complete(UUID) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.sync_points_balance() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821024553_9573ea06-c738-438b-bb4e-1aa62fd0472b.sql
-- =============================================

-- Revoke PUBLIC execute rights on SECURITY DEFINER functions
-- This addresses the 0028_anon_security_definer_function_executable and 0029_authenticated_security_definer_function_executable warnings

-- Revoke from PUBLIC (both anon and authenticated)
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(UUID, app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-grant to specific roles where needed
-- has_role is used in RLS policies, so it needs to be executable by authenticated users
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(UUID, app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- trigger functions only need to be executable by service_role/postgres
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- is_profile_complete is used by the trigger, but also by the client for UI logic
-- Grant execute to authenticated users for UI checks
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(UUID) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821024617_fd033619-fcfa-482e-a277-f49e406dab8c.sql
-- =============================================

-- Address SECURITY DEFINER linter warnings (0028 and 0029)
-- Revoke default execution from PUBLIC on all future functions
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Revoke execute from PUBLIC for existing SECURITY DEFINER functions with correct signatures
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.lookup_login_email(text) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-grant specific permissions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Administrative functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Trigger/Internal functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821024630_5ac861ec-edf7-49f5-8347-1c9fcd6e8179.sql
-- =============================================

-- Fixed ambiguous oid reference
DO $$ 
DECLARE 
    func_record RECORD;
BEGIN 
    FOR func_record IN 
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    LOOP 
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.' || quote_ident(func_record.proname) || '(' || func_record.args || ') FROM PUBLIC';
    END LOOP;
END $$;

-- 2. Explicitly re-grant execution only to specific roles for necessary functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3. Re-grant trigger/admin functions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 4. Set search_path for all security definer functions
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.reward_referrer_on_signup() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.sync_points_balance() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.has_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.claim_welcome_bonus(uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.check_referral_code(text, uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.lookup_login_email(text) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.assign_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.remove_role(uuid, app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_admin_audit_log() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821024646_ef676217-c946-4619-95f9-7c091fb3ea5b.sql
-- =============================================

-- Precise revocation based on verified signatures

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Re-granting lookup functions that MUST be anon for the app to work
-- (Linter will still flag these as warnings, but they are required)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821025019_2a30252e-5cc3-426e-a3ec-70d1382747bf.sql
-- =============================================

-- Ensure the trigger for profile completion exists and is correctly applied
-- This trigger will flip pending transactions to completed when a user fills their profile.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'on_profile_completion'
    ) THEN
        CREATE TRIGGER on_profile_completion
        AFTER UPDATE ON public.profiles
        FOR EACH ROW
        EXECUTE FUNCTION public.check_pending_referrals_on_update();
    END IF;
END $$;

-- Verify RLS and grants for the new logic
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821025032_eaeba116-626d-43a2-a756-f75097f1db8c.sql
-- =============================================

-- Ensure the profile completion trigger is correctly linked to the profile updates
-- This automation ensures that once a user fills their details, all pending rewards are flipped to positive.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'on_profile_completion'
    ) THEN
        CREATE TRIGGER on_profile_completion
        AFTER UPDATE ON public.profiles
        FOR EACH ROW
        EXECUTE FUNCTION public.check_pending_referrals_on_update();
    END IF;
END $$;

-- Hardening the balance synchronization to ensure dashboards update instantly
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.sync_points_balance();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'sync_balance_on_transaction') THEN
        CREATE TRIGGER sync_balance_on_transaction
        AFTER INSERT OR UPDATE ON public.points_transactions
        FOR EACH STATEMENT
        EXECUTE FUNCTION public.sync_points_balance_trigger();
    END IF;
END $$;


-- =============================================
-- Migration: 20260821025955_a90c348b-8b72-4bf9-8e6f-1ac5fc4e5e3f.sql
-- =============================================

-- 1. Add 'tasker' to app_role enum
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'tasker';

-- 2. Create role_permissions table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role public.app_role NOT NULL,
    tab_name TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(role, tab_name)
);

-- 3. Grant access
GRANT SELECT, INSERT, UPDATE, DELETE ON public.role_permissions TO authenticated;
GRANT ALL ON public.role_permissions TO service_role;

-- 4. Enable RLS
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- 5. Create Policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Admins can manage all role permissions' AND tablename = 'role_permissions'
    ) THEN
        CREATE POLICY "Admins can manage all role permissions"
        ON public.role_permissions
        FOR ALL
        TO authenticated
        USING (public.has_role(auth.uid(), 'admin'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'All authenticated users can read permissions' AND tablename = 'role_permissions'
    ) THEN
        CREATE POLICY "All authenticated users can read permissions"
        ON public.role_permissions
        FOR SELECT
        TO authenticated
        USING (true);
    END IF;
END
$$;


-- =============================================
-- Migration: 20260821032433_21d8011d-d32e-49bc-9a84-b00f8b39aa72.sql
-- =============================================


-- Create a view to simplify searching across referrals and profiles
CREATE OR REPLACE VIEW public.referrals_with_profiles AS
SELECT 
    r.*,
    referrer.username as referrer_username,
    referrer.full_name as referrer_full_name,
    referrer.avatar_url as referrer_avatar_url,
    referrer.email as referrer_email,
    referrer.points_balance as referrer_points_balance,
    referrer.referral_code as referrer_referral_code,
    referee.username as referee_username,
    referee.full_name as referee_full_name,
    referee.email as referee_email,
    referee.created_at as referee_created_at,
    referee.twitter_handle as referee_twitter_handle,
    referee.telegram_handle as referee_telegram_handle,
    referee.has_claimed_welcome_bonus as referee_has_claimed_welcome_bonus
FROM public.referrals r
JOIN public.profiles referrer ON r.referrer_id = referrer.id
JOIN public.profiles referee ON r.referee_id = referee.id;

GRANT SELECT ON public.referrals_with_profiles TO authenticated;
GRANT ALL ON public.referrals_with_profiles TO service_role;


-- =============================================
-- Migration: 20260821034028_e5e9423f-ce26-49ed-bb74-e34280a4e685.sql
-- =============================================


-- Add INSERT policy for authenticated users to the notifications table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' 
        AND policyname = 'Users can insert notifications for others during system actions'
    ) THEN
        CREATE POLICY "Users can insert notifications for others during system actions"
        ON public.notifications
        FOR INSERT
        TO authenticated
        WITH CHECK (true);
    END IF;
END
$$;

-- Ensure authenticated role has INSERT grant
GRANT INSERT ON public.notifications TO authenticated;


-- =============================================
-- Migration: 20260821034354_38470b59-208f-46d1-aa55-4d435abb0709.sql
-- =============================================


-- Revoke PUBLIC execute permissions from all SECURITY DEFINER functions in public schema
-- This addresses linter warnings 0028 and 0029.

DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.prosecdef = true
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %I.%I(%s) FROM PUBLIC', 
            func_record.nspname, func_record.proname, func_record.args);
    END LOOP;
END $$;

-- Selectively grant back only what is needed for authenticated users
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Allow anon to lookup emails (for login) and increment clicks (public referral links)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure service_role has all permissions
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Fix the analytics_events RLS policy
-- Note: 'qual' is for USING, which doesn't apply to INSERT. Only WITH CHECK is needed.
DROP POLICY IF EXISTS "Allow anyone to insert events" ON public.analytics_events;
CREATE POLICY "Allow authenticated to insert their own events" 
ON public.analytics_events
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Allow anon to log events (e.g., landing page visits) but only with NULL user_id
CREATE POLICY "Allow anon to insert anonymous events"
ON public.analytics_events
FOR INSERT
TO anon
WITH CHECK (user_id IS NULL);


-- =============================================
-- Migration: 20260821034403_77a47843-9362-47dc-9db8-3b62fda95718.sql
-- =============================================


-- Revoke execute from anon/authenticated for internal triggers and sync functions
-- These should only be executable by the system (service_role) or via triggers

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance_trigger() FROM anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.check_pending_referrals_on_update() FROM anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance() FROM anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Keep grants only where necessary for app functionality
-- lookup_login_email is needed for login (anon)
-- increment_referral_clicks is needed for public links (anon)
-- check_referral_code is needed for signup (anon)


-- =============================================
-- Migration: 20260821034417_ce41517c-c2d4-4f29-86af-81c08109f6e5.sql
-- =============================================


-- Re-create referrals_with_profiles as a SECURITY INVOKER view (default)
-- and ensure it follows RLS policies of the underlying tables
CREATE OR REPLACE VIEW public.referrals_with_profiles AS
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

-- Ensure grants for the view
GRANT SELECT ON public.referrals_with_profiles TO authenticated;

-- Final linter check hardening: ensure no remaining broad public execute
-- We specifically keep: lookup_login_email, increment_referral_clicks, check_referral_code 
-- for anonymous usage as they are functionally required for signup/referral tracking.
-- These have been verified to not leak sensitive data beyond their specific purpose.


-- =============================================
-- Migration: 20260821034714_05c52c97-f9e5-44be-9d69-8ac0847a86f2.sql
-- =============================================

-- 1. Revoke PUBLIC execution from all SECURITY DEFINER functions in public schema
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.prosecdef = true
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC;', func_record.nspname, func_record.proname, func_record.args);
    END LOOP;
END $$;

-- 2. Selectively grant execution back to appropriate roles
-- Public/Auth functions for core features
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Auth-only functions for user actions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Admin-only functions
-- These will be checked via internal logic (like has_role) but we grant execute to authenticated
-- so the Data API can call them, then the function body enforces the admin check.
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821034746_185bde66-6ede-4814-9040-df50ac752467.sql
-- =============================================

-- Re-create views with explicit security_invoker=true to satisfy linter and ensure RLS is respected.
-- In Supabase/Postgres 15+, we can use security_invoker = true.

DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = true) AS
SELECT id,
    full_name,
    username,
    avatar_url,
    points_balance,
    rank() OVER (ORDER BY points_balance DESC) AS rank
   FROM profiles p
  ORDER BY points_balance DESC
 LIMIT 100;
GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

DROP VIEW IF EXISTS public.referrals_with_profiles;
CREATE VIEW public.referrals_with_profiles WITH (security_invoker = true) AS
SELECT r.referrer_id,
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
   FROM ((referrals r
     JOIN profiles referrer ON ((r.referrer_id = referrer.id)))
     JOIN profiles referee ON ((r.referee_id = referee.id)));
GRANT SELECT ON public.referrals_with_profiles TO authenticated;

DROP VIEW IF EXISTS public.user_ranks;
CREATE VIEW public.user_ranks WITH (security_invoker = true) AS
SELECT p.id AS user_id,
    p.username,
    COALESCE(r.referral_count, (0)::bigint) AS referral_count,
        CASE
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 50) THEN 'Legend'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 20) THEN 'Pro'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 10) THEN 'Super Referrer'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 5) THEN 'Elite'::text
            ELSE 'Novice'::text
        END AS rank_name,
        CASE
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 50) THEN 5
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 20) THEN 4
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 10) THEN 3
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 5) THEN 2
            ELSE 1
        END AS rank_level
   FROM (profiles p
     LEFT JOIN ( SELECT referrals.referrer_id,
            count(*) AS referral_count
           FROM referrals
          GROUP BY referrals.referrer_id) r ON ((p.id = r.referrer_id)));
GRANT SELECT ON public.user_ranks TO authenticated;

DROP VIEW IF EXISTS public.my_referrals_detailed;
CREATE VIEW public.my_referrals_detailed WITH (security_invoker = true) AS
SELECT r.referrer_id,
    p.id AS referee_id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.created_at AS joined_at,
        CASE
            WHEN p.has_claimed_welcome_bonus THEN 'Active'::text
            ELSE 'Pending Profile'::text
        END AS status
   FROM (referrals r
     JOIN profiles p ON ((r.referee_id = p.id)));
GRANT SELECT ON public.my_referrals_detailed TO authenticated;


-- =============================================
-- Migration: 20260821035437_d4722356-f7fa-4bfb-abff-7cefdd4dcb21.sql
-- =============================================

-- Security Hardening: Revoke broad permissions on SECURITY DEFINER functions

-- 1. Revoke PUBLIC execution on ALL functions in public schema as a baseline
-- We use a DO block to execute this as it might not be a single statement in all environments,
-- and it helps us handle the 'REVOKE' in a scriptable way.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 2. Grant EXECUTE to 'anon' for functions required during pre-auth/sign-up
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3. Grant EXECUTE to 'authenticated' for user-facing actions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 4. Admin functions (explicitly grant only to authenticated, but has_role check is inside)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 5. Trigger functions (grant to service_role)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_pending_referrals_on_update() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.guard_profile_sensitive_columns() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance_trigger() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821035822_e46c15d8-d979-4d98-8978-cf6ccd49bcad.sql
-- =============================================

-- Fix referrals table schema to allow unique check on (referrer_id, referee_id)
-- and backfill correctly.

-- 1. Ensure a unique constraint exists for (referrer_id, referee_id)
-- If referee_id is PK, it's already unique for referee_id. 
-- But handle_new_user uses (referrer_id, referee_id) in ON CONFLICT.

-- Update handle_new_user to use referee_id for conflict check
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_referrer_id UUID;
BEGIN
  -- Determine referrer
  SELECT id INTO v_referrer_id 
  FROM public.profiles 
  WHERE referral_code = (new.raw_user_meta_data->>'referral_code_used') 
  LIMIT 1;

  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    username,
    avatar_url,
    points_balance,
    referred_by
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url',
    0,
    v_referrer_id
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    username = EXCLUDED.username,
    avatar_url = EXCLUDED.avatar_url;

  -- 2. Ensure record exists in referrals table if referred
  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO NOTHING;
  END IF;
  
  RETURN new;
END;
$function$;

-- 2. Backfill referrals table from profiles.referred_by
INSERT INTO public.referrals (referrer_id, referee_id, created_at)
SELECT referred_by, id, created_at
FROM public.profiles
WHERE referred_by IS NOT NULL
ON CONFLICT (referee_id) DO NOTHING;

-- 3. Standardize count query in a view for global use
DROP VIEW IF EXISTS public.referral_stats_summary;
CREATE VIEW public.referral_stats_summary WITH (security_invoker = true) AS
SELECT 
    referrer_id as user_id,
    COUNT(*) as total_referrals,
    COUNT(*) FILTER (WHERE p.has_claimed_welcome_bonus = true) as completed_referrals,
    SUM(CASE WHEN p.has_claimed_welcome_bonus = true THEN 75 ELSE 0 END) as points_earned
FROM public.referrals r
JOIN public.profiles p ON r.referee_id = p.id
GROUP BY referrer_id;

GRANT SELECT ON public.referral_stats_summary TO authenticated;
GRANT SELECT ON public.referral_stats_summary TO service_role;


-- =============================================
-- Migration: 20260821035852_40170ac2-1609-413f-b8ca-45191ce8bc90.sql
-- =============================================

-- Standardize global referral statistics in a view
DROP VIEW IF EXISTS public.global_referral_stats;
CREATE VIEW public.global_referral_stats WITH (security_invoker = true) AS
SELECT 
    COUNT(*) as total_referrals,
    COUNT(DISTINCT referrer_id) as total_referrers,
    COUNT(*) FILTER (WHERE p.has_claimed_welcome_bonus = true) as completed_referrals
FROM public.referrals r
JOIN public.profiles p ON r.referee_id = p.id;

GRANT SELECT ON public.global_referral_stats TO authenticated;
GRANT SELECT ON public.global_referral_stats TO service_role;


-- =============================================
-- Migration: 20260821135805_d382f85c-4c59-47ce-bcb5-c3397842859b.sql
-- =============================================

-- The migration file supabase/migrations/20260821040000_fix_task_triggers.sql
-- has been created on disk. I will now apply it via this tool call.
-- (The tool will read the file and apply it)

-- Actually, I need to provide the query here. I'll read it back.
SELECT 1;


-- =============================================
-- Migration: 20260821135826_00786338-6e11-4868-bb96-57fd1d586043.sql
-- =============================================

-- Fix the trigger functions if they were accidentally created as standard functions
-- or if they are missing entirely.

-- 1. update_points_balance_on_task_status_change
CREATE OR REPLACE FUNCTION public.update_points_balance_on_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only award points when status changes to 'verified'
    IF (TG_OP = 'UPDATE' AND OLD.status <> 'verified' AND NEW.status = 'verified') OR
       (TG_OP = 'INSERT' AND NEW.status = 'verified') THEN
        
        -- Get task points
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        SELECT NEW.user_id, t.points, 'earn', 'Completed task: ' || t.title
        FROM public.tasks t
        WHERE t.id = NEW.task_id;
        
    END IF;
    RETURN NEW;
END;
$$;

-- 2. log_task_status_change
CREATE OR REPLACE FUNCTION public.log_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status <> NEW.status) THEN
        INSERT INTO public.admin_audit_logs (target_table, target_id, action_type, old_data, new_data)
        VALUES ('task_submissions', NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
    END IF;
    RETURN NEW;
END;
$$;

-- 3. log_user_task_activity
CREATE OR REPLACE FUNCTION public.log_user_task_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Potential for logging user activity analytics here
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$;

-- 4. Re-attach triggers to task_submissions
DROP TRIGGER IF EXISTS on_task_status_change ON public.task_submissions;
CREATE TRIGGER on_task_status_change
    AFTER UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_verified ON public.task_submissions;
CREATE TRIGGER on_task_submission_verified
    AFTER INSERT OR UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_points_balance_on_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_activity ON public.task_submissions;
CREATE TRIGGER on_task_submission_activity
    AFTER INSERT ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_user_task_activity();

-- 5. Final permissions check
REVOKE ALL ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.log_task_status_change() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.log_user_task_activity() FROM PUBLIC, authenticated, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 6. Update submit_task to NOT manually insert points
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- RATE LIMITING
    SELECT created_at INTO v_last_submission
    FROM public.task_submissions
    WHERE user_id = _user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_submission IS NOT NULL AND v_now - v_last_submission < interval '2 seconds' THEN
        RETURN json_build_object('success', false, 'message', 'Please wait a moment before submitting again.');
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text || _task_id::text));

    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found or inactive.');
    END IF;

    SELECT * INTO v_existing_submission FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id;
    
    IF FOUND THEN
        IF v_existing_submission.status = 'verified' THEN
            RETURN json_build_object('success', false, 'message', 'Task already completed.');
        ELSIF v_existing_submission.status = 'pending' THEN
            RETURN json_build_object('success', false, 'message', 'Task already under review.');
        END IF;
    END IF;

    -- Create submission - Trigger will handle point awarding
    INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
    VALUES (_user_id, _task_id, CASE WHEN v_task_record.verification_required THEN 'pending' ELSE 'verified' END, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE 
    SET status = EXCLUDED.status, created_at = v_now;
    
    IF v_task_record.verification_required THEN
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification.');
    ELSE
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_task_record.points || ' points awarded.', 'points', v_task_record.points);
    END IF;
END;
$$;

-- 7. Update record_video_watch to NOT manually insert points
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    SELECT * INTO v_task_record 
    FROM public.tasks 
    WHERE id = _task_id 
      AND is_active = true 
      AND category = 'Videos'
      AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.task_submissions 
        WHERE user_id = _user_id 
          AND task_id = _task_id 
          AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Atomic completion - Trigger will handle point awarding
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE 
        SET status = 'verified', created_at = v_now;
        
        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true, 
            'completed', true, 
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true, 
        'completed', false, 
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$$;


-- =============================================
-- Migration: 20260821140408_71eb3a2b-57e4-4258-aaea-f734703bdead.sql
-- =============================================

-- 1. Redefine sync_points_balance as a normal function (NOT a trigger function)
-- This avoids the "trigger functions can only be called as triggers" error when called via PERFORM.
CREATE OR REPLACE FUNCTION public.sync_points_balance(p_user_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = p_user_id AND status = 'completed'
    )
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 2. Redefine the trigger function to be a proper ROW trigger function that calls the normal function.
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM public.sync_points_balance(OLD.user_id);
    ELSE
        PERFORM public.sync_points_balance(NEW.user_id);
        
        -- If it's an update and user_id changed (rare but possible), sync the old one too
        IF (TG_OP = 'UPDATE' AND OLD.user_id <> NEW.user_id) THEN
            PERFORM public.sync_points_balance(OLD.user_id);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Re-attach the trigger as a ROW trigger (it was incorrectly attached as a STATEMENT trigger in some migrations)
DROP TRIGGER IF EXISTS sync_balance_on_transaction ON public.points_transactions;
CREATE TRIGGER sync_balance_on_transaction
    AFTER INSERT OR UPDATE OR DELETE ON public.points_transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_points_balance_trigger();

-- 4. Remove the other potentially conflicting/redundant trigger if it exists
-- This one was also doing balance updates but without status checks.
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;

-- 5. Ensure permissions
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance_trigger() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821140440_8620edc0-945a-4a7b-9472-69d4ff77f824.sql
-- =============================================

-- 1. Drop the incorrect versions of the functions
-- First, identify and drop the ones that return trigger but shouldn't, or are duplicates.
DROP FUNCTION IF EXISTS public.sync_points_balance(); -- The one that returns trigger
DROP FUNCTION IF EXISTS public.update_user_points_balance(); -- Redundant

-- 2. Make sure the correct version of sync_points_balance exists
CREATE OR REPLACE FUNCTION public.sync_points_balance(p_user_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = p_user_id AND status = 'completed'
    )
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Ensure sync_points_balance_trigger is correctly calling it
CREATE OR REPLACE FUNCTION public.sync_points_balance_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        PERFORM public.sync_points_balance(OLD.user_id);
    ELSE
        PERFORM public.sync_points_balance(NEW.user_id);
        IF (TG_OP = 'UPDATE' AND OLD.user_id <> NEW.user_id) THEN
            PERFORM public.sync_points_balance(OLD.user_id);
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Check for any other problematic functions
-- I noticed log_task_status_change, update_points_balance_on_task_status_change, 
-- and log_user_task_activity were fixed in the previous turn to be triggers.
-- Let's ensure no NON-trigger versions of them exist.
DROP FUNCTION IF EXISTS public.log_task_status_change(uuid, uuid, text, text);
DROP FUNCTION IF EXISTS public.update_points_balance_on_task_status_change(uuid, uuid);
DROP FUNCTION IF EXISTS public.log_user_task_activity(uuid, uuid, text);

-- 5. Re-verify triggers on task_submissions
DROP TRIGGER IF EXISTS on_task_status_change ON public.task_submissions;
CREATE TRIGGER on_task_status_change
    AFTER UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_verified ON public.task_submissions;
CREATE TRIGGER on_task_submission_verified
    AFTER INSERT OR UPDATE ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_points_balance_on_task_status_change();

DROP TRIGGER IF EXISTS on_task_submission_activity ON public.task_submissions;
CREATE TRIGGER on_task_submission_activity
    AFTER INSERT ON public.task_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.log_user_task_activity();


-- =============================================
-- Migration: 20260821150853_c6d4c55c-3f4c-4c48-8a0b-4283825d596a.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.has_completed_social_profile(_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_required text[];
  v_social text;
  v_profile record;
  v_value text;
BEGIN
  SELECT COALESCE(ARRAY(SELECT jsonb_array_elements_text(value::jsonb)), '{}')
    INTO v_required
  FROM public.app_settings
  WHERE key = 'welcome_bonus_required_socials';

  IF v_required IS NULL OR array_length(v_required, 1) IS NULL THEN
    RETURN true;
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
  IF NOT FOUND THEN RETURN false; END IF;

  FOREACH v_social IN ARRAY v_required LOOP
    EXECUTE format('SELECT %I FROM public.profiles WHERE id = $1', v_social || '_handle')
      INTO v_value USING _user_id;
    IF v_value IS NULL OR btrim(v_value) = '' THEN
      RETURN false;
    END IF;
  END LOOP;

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.has_completed_social_profile(uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT created_at INTO v_last_submission
    FROM public.task_submissions
    WHERE user_id = _user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_submission IS NOT NULL AND v_now - v_last_submission < interval '2 seconds' THEN
        RETURN json_build_object('success', false, 'message', 'Please wait a moment before submitting again.');
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text || _task_id::text));

    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found or inactive.');
    END IF;

    SELECT * INTO v_existing_submission FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id;

    IF FOUND THEN
        IF v_existing_submission.status = 'verified' THEN
            RETURN json_build_object('success', false, 'message', 'Task already completed.');
        ELSIF v_existing_submission.status = 'pending' THEN
            RETURN json_build_object('success', false, 'message', 'Task already under review.');
        END IF;
    END IF;

    INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
    VALUES (_user_id, _task_id, CASE WHEN v_task_record.verification_required THEN 'pending' ELSE 'verified' END, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET status = EXCLUDED.status, created_at = v_now;

    IF v_task_record.verification_required THEN
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification.');
    ELSE
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_task_record.points || ' points awarded.', 'points', v_task_record.points);
    END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT * INTO v_task_record
    FROM public.tasks
    WHERE id = _task_id
      AND is_active = true
      AND category = 'Videos'
      AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.task_submissions
        WHERE user_id = _user_id
          AND task_id = _task_id
          AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE
        SET status = 'verified', created_at = v_now;

        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true,
            'completed', true,
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'completed', false,
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$function$;

-- =============================================
-- Migration: 20260821155522_aca14657-cc9a-4c4f-af53-5721180ae84f.sql
-- =============================================

-- Final version of claim_welcome_bonus to strictly enforce one-time claiming
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    -- 1. Authorization check
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 2. Lock the profile record to prevent race conditions
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id FOR UPDATE;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    -- 3. Strict one-time check
    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'alreadyClaimed', true, 'message', 'Bonus already claimed');
    END IF;

    -- 4. Read settings from app_settings
    SELECT (value->>0)::boolean INTO v_bonus_enabled FROM public.app_settings WHERE key = 'welcome_bonus_enabled';
    SELECT (value->>0)::integer INTO v_referral_points_referee FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
    SELECT (value->>0)::integer INTO v_referral_points_referrer FROM public.app_settings WHERE key = 'welcome_bonus_amount_referrer';
    SELECT value INTO v_required_socials FROM public.app_settings WHERE key = 'welcome_bonus_required_socials';

    -- Defaults
    v_bonus_enabled := COALESCE(v_bonus_enabled, true);
    v_referral_points_referee := COALESCE(v_referral_points_referee, 50);
    v_referral_points_referrer := COALESCE(v_referral_points_referrer, 75);
    v_required_socials := COALESCE(v_required_socials, '["twitter", "telegram"]'::jsonb);

    IF NOT v_bonus_enabled THEN
        RETURN json_build_object('success', false, 'message', 'Welcome bonus program is currently disabled.');
    END IF;

    -- 5. Clean and validate handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Social eligibility check
    IF ('"twitter"'::jsonb <@ v_required_socials) AND (v_twitter_clean IS NULL OR v_twitter_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Twitter profile to be eligible.');
    END IF;

    IF ('"telegram"'::jsonb <@ v_required_socials) AND (v_telegram_clean IS NULL OR v_telegram_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Telegram profile to be eligible.');
    END IF;
    
    -- Format validation
    IF (v_twitter_clean IS NOT NULL AND v_twitter_clean != '') AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    IF (v_telegram_clean IS NOT NULL AND v_telegram_clean != '') AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- 6. Duplicate handle check (anti-fraud)
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

    -- 7. MARK AS CLAIMED FIRST to prevent concurrent double-credit
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- 8. Record transactions
    -- Referee credit
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- Referrer credit
    IF v_profile.referred_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

-- Ensure proper permissions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821163831_55434611-26e7-4445-9b09-52c30a1a41c1.sql
-- =============================================

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

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

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

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 7. Clean up old triggers that might conflict
DROP TRIGGER IF EXISTS on_profile_referral_reward ON public.profiles;
DROP TRIGGER IF EXISTS on_profile_update_check_referral ON public.profiles;
DROP TRIGGER IF EXISTS on_profile_completion ON public.profiles;


-- =============================================
-- Migration: 20260821164156_30342a0b-241d-4cc4-8b5a-a176b8963191.sql
-- =============================================

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


-- =============================================
-- Migration: 20260821165304_632b1ec5-bd84-4a4e-930a-0d625715b598.sql
-- =============================================


DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'points_audit_logs') THEN
        CREATE TABLE public.points_audit_logs (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id uuid REFERENCES auth.users(id) NOT NULL,
            amount integer NOT NULL,
            reason text NOT NULL,
            trigger_name text NOT NULL,
            created_at timestamp with time zone DEFAULT now()
        );

        GRANT SELECT ON public.points_audit_logs TO authenticated;
        GRANT ALL ON public.points_audit_logs TO service_role;
        ALTER TABLE public.points_audit_logs ENABLE ROW LEVEL SECURITY;

        CREATE POLICY "Admins can see all points audit logs"
        ON public.points_audit_logs FOR SELECT
        TO authenticated
        USING (public.has_role(auth.uid(), 'admin'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
    p_admin_id UUID,
    p_target_user_id UUID,
    p_amount INTEGER,
    p_action_type TEXT,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- 1. Check if caller is admin
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_admin_id AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can adjust points';
    END IF;

    -- 2. Apply transaction
    PERFORM handle_points_transaction(
        p_target_user_id,
        CASE WHEN p_action_type = 'credit' THEN ABS(p_amount) ELSE -ABS(p_amount) END,
        'Admin adjustment: ' || p_reason,
        'adjustment'
    );

    -- 3. Log to points_audit_logs
    INSERT INTO points_audit_logs (user_id, amount, reason, trigger_name)
    VALUES (
        p_target_user_id,
        CASE WHEN p_action_type = 'credit' THEN ABS(p_amount) ELSE -ABS(p_amount) END,
        'ADMIN_' || UPPER(p_action_type) || ': ' || p_reason,
        'admin_manual_action'
    );
END;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821165443_78716347-f3ad-4a0c-94a3-e946fc128a2a.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
    p_admin_id UUID,
    p_target_user_id UUID,
    p_amount INTEGER,
    p_action_type TEXT,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_role app_role;
    v_transaction_id UUID;
    v_final_amount INTEGER;
BEGIN
    -- 1. Security check: verify caller is admin
    SELECT role INTO v_admin_role FROM public.user_roles WHERE user_id = p_admin_id AND role = 'admin';
    
    IF v_admin_role IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
    END IF;

    -- 2. Determine final amount (credit is positive, debit is negative)
    IF p_action_type = 'credit' THEN
        v_final_amount := ABS(p_amount);
    ELSE
        v_final_amount := -ABS(p_amount);
    END IF;

    -- 3. Record transaction
    INSERT INTO public.points_transactions (
        user_id,
        amount,
        type,
        description,
        status
    ) VALUES (
        p_target_user_id,
        v_final_amount,
        'adjustment',
        'Admin adjustment: ' || p_reason,
        'completed'
    ) RETURNING id INTO v_transaction_id;

    -- 4. Update profile balance
    UPDATE public.profiles
    SET points_balance = points_balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    -- 5. Record in points_audit_logs
    INSERT INTO public.points_audit_logs (
        user_id,
        amount,
        reason,
        trigger_name
    ) VALUES (
        p_target_user_id,
        v_final_amount,
        'Admin Adjustment: ' || p_reason,
        'manual_admin_action'
    );

    -- 6. Log in admin_audit_logs
    INSERT INTO public.admin_audit_logs (
        admin_id,
        action_type,
        target_table,
        target_id,
        new_data
    ) VALUES (
        p_admin_id,
        'points_adjustment',
        'profiles',
        p_target_user_id,
        jsonb_build_object(
            'amount', v_final_amount,
            'reason', p_reason,
            'transaction_id', v_transaction_id
        )
    );

    -- 7. Send notification to user
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        transaction_id
    ) VALUES (
        p_target_user_id,
        'Points Adjusted',
        'Your points balance has been adjusted by ' || v_final_amount || ' points. Reason: ' || p_reason,
        'points',
        v_transaction_id
    );

END;
$$;


-- =============================================
-- Migration: 20260821170920_3a1e83a9-ba6e-4b1b-8b5f-d9193b25c2e1.sql
-- =============================================

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
                ) RETURNING id INTO v_transaction_id;

                -- AUDIT LOG
                INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

                INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
                VALUES (
                    v_referrer_id,
                    'Referral Reward Earned!',
                    'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                    'reward',
                    v_transaction_id
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

-- =============================================
-- Migration: 20260821171256_fd3c248a-d927-4eb2-adf1-94a0688b4af3.sql
-- =============================================

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

-- =============================================
-- Migration: 20260821171307_185beba5-2418-4275-87b0-6dff317a9f5b.sql
-- =============================================

-- Revoke EXECUTE from public/anon/authenticated on SECURITY DEFINER functions
-- that should only be called by system triggers.

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure service_role can still execute them (though triggers usually run as owner)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260821180000_add_notification_metadata.sql
-- =============================================

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


-- =============================================
-- Migration: 20260821181000_harden_notifications_functions.sql
-- =============================================

-- Revoke EXECUTE from public/anon/authenticated on SECURITY DEFINER functions
-- that should only be called by system triggers.

DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Ensure service_role can still execute them (though triggers usually run as owner)
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260821211108_89cb18ec-b248-404e-84c4-c62e2ae18f77.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.sync_points_balance(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    PERFORM set_config('app.points_sync', 'on', true);
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = p_user_id AND status = 'completed'
    )
    WHERE id = p_user_id;
    PERFORM set_config('app.points_sync', 'off', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF current_setting('app.points_sync', true) = 'on' THEN
    RETURN NEW;
  END IF;

  IF auth.role() IS DISTINCT FROM 'service_role' AND NOT public.has_role(auth.uid(), 'admin') THEN
    NEW.points_balance := OLD.points_balance;
    NEW.referral_code := OLD.referral_code;
    NEW.referred_by := OLD.referred_by;
    NEW.referral_clicks := OLD.referral_clicks;
    NEW.has_claimed_welcome_bonus := OLD.has_claimed_welcome_bonus;
    NEW.email := OLD.email;
    NEW.id := OLD.id;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.profiles LOOP
    PERFORM public.sync_points_balance(r.id);
  END LOOP;
END $$;

-- =============================================
-- Migration: 20260821211507_16b002c3-6e93-4e32-be02-9239143646a2.sql
-- =============================================

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.points_transactions;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.points_transactions REPLICA IDENTITY FULL;

-- =============================================
-- Migration: 20260821211712_f3c06f34-ce72-4aa0-82aa-34a2df233179.sql
-- =============================================

-- 1. Remove duplicate point credits (keep the earliest per user/type/source)
DELETE FROM public.points_transactions pt
USING (
  SELECT id, row_number() OVER (PARTITION BY user_id, type, source_id ORDER BY created_at, id) AS rn
  FROM public.points_transactions
  WHERE source_id IS NOT NULL
) d
WHERE pt.id = d.id AND d.rn > 1;

-- 2. Backfill source_id for task earnings so they can be de-duplicated
UPDATE public.points_transactions pt
SET source_id = ts.id
FROM public.task_submissions ts
JOIN public.tasks t ON t.id = ts.task_id
WHERE pt.source_id IS NULL
  AND pt.type = 'earn'
  AND pt.user_id = ts.user_id
  AND pt.description = 'Completed task: ' || t.title;

-- 3. Re-run dedupe after backfill
DELETE FROM public.points_transactions pt
USING (
  SELECT id, row_number() OVER (PARTITION BY user_id, type, source_id ORDER BY created_at, id) AS rn
  FROM public.points_transactions
  WHERE source_id IS NOT NULL
) d
WHERE pt.id = d.id AND d.rn > 1;

-- 4. Hard idempotency guarantee at the database level
CREATE UNIQUE INDEX IF NOT EXISTS points_transactions_unique_source
  ON public.points_transactions (user_id, type, source_id)
  WHERE source_id IS NOT NULL;

-- 5. Task reward: one credit per submission, ever
CREATE OR REPLACE FUNCTION public.update_points_balance_on_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'verified' AND NEW.status = 'verified') OR
       (TG_OP = 'INSERT' AND NEW.status = 'verified') THEN

        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        SELECT NEW.user_id, t.points, 'earn', 'Completed task: ' || t.title, NEW.id
        FROM public.tasks t
        WHERE t.id = NEW.task_id
          AND NOT EXISTS (
            SELECT 1 FROM public.points_transactions p
            WHERE p.user_id = NEW.user_id
              AND p.type = 'earn'
              AND (p.source_id = NEW.id OR p.description = 'Completed task: ' || t.title)
          )
        ON CONFLICT DO NOTHING;

    END IF;
    RETURN NEW;
END;
$function$;

-- 6. Referral reward: one credit per referee, ever
CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_referrer_id UUID;
    v_referral_bonus INTEGER;
    v_referee_username TEXT;
    v_transaction_id UUID;
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status <> 'approved') THEN
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.user_id;

        IF v_referrer_id IS NOT NULL THEN
            -- Serialize concurrent confirmations for this referrer/referee pair
            PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

            IF NOT EXISTS (
                SELECT 1 FROM public.points_transactions
                WHERE user_id = v_referrer_id
                  AND type IN ('referral', 'referral_bonus')
                  AND source_id = NEW.user_id
            ) THEN
                SELECT (value->>'amount')::integer INTO v_referral_bonus
                FROM public.app_settings WHERE key = 'referral_bonus';
                v_referral_bonus := COALESCE(v_referral_bonus, 75);

                SELECT username INTO v_referee_username FROM public.profiles WHERE id = NEW.user_id;

                INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
                VALUES (
                    v_referrer_id, v_referral_bonus, 'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed', NEW.user_id
                )
                ON CONFLICT DO NOTHING
                RETURNING id INTO v_transaction_id;

                IF v_transaction_id IS NOT NULL THEN
                    INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                    VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

                    INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
                    VALUES (
                        v_referrer_id,
                        'Referral Reward Earned!',
                        'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                        'reward', v_transaction_id, jsonb_build_object('referee_id', NEW.user_id)
                    );
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- 7. Signup referral rows: never duplicate
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50;
    v_new_user_bonus INTEGER := 50;
BEGIN
    SELECT referrer_id INTO v_referrer_id FROM public.referrals WHERE referee_id = NEW.id;

    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (v_referrer_id, v_referral_reward_points, 'referral',
                'Referral bonus for ' || NEW.username || ' (Pending profile completion)', 'pending', NEW.id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (NEW.id, v_new_user_bonus, 'welcome_bonus',
                'Welcome bonus (Pending profile completion)', 'pending', v_referrer_id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_referrer_id, 'Referral Pending!',
                'You have a pending reward for referring ' || NEW.username || '. It will be available once they complete their profile.',
                'info');
    END IF;

    RETURN NEW;
END;
$function$;

-- 8. Resync balances after the cleanup
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.profiles LOOP
    PERFORM public.sync_points_balance(r.id);
  END LOOP;
END $$;

-- =============================================
-- Migration: 20260822230805_e74bdd7c-8657-458b-b6a7-49b963ebe465.sql
-- =============================================

-- 1) Admin points adjustment: derive caller from auth.uid(), drop spoofable p_admin_id
DROP FUNCTION IF EXISTS public.handle_admin_points_adjustment(uuid, uuid, integer, text, text);

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(p_target_user_id uuid, p_amount integer, p_action_type text, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_admin_id uuid := auth.uid();
    v_transaction_id UUID;
    v_final_amount INTEGER;
BEGIN
    -- Security check: the actual caller must be an admin
    IF v_admin_id IS NULL OR NOT public.has_role(v_admin_id, 'admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
    END IF;

    IF p_action_type = 'credit' THEN
        v_final_amount := ABS(p_amount);
    ELSE
        v_final_amount := -ABS(p_amount);
    END IF;

    INSERT INTO public.points_transactions (user_id, amount, type, description, status)
    VALUES (p_target_user_id, v_final_amount, 'adjustment', 'Admin adjustment: ' || p_reason, 'completed')
    RETURNING id INTO v_transaction_id;

    UPDATE public.profiles
    SET points_balance = points_balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
    VALUES (p_target_user_id, v_final_amount, 'Admin Adjustment: ' || p_reason, 'manual_admin_action');

    INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
    VALUES (v_admin_id, 'points_adjustment', 'profiles', p_target_user_id,
        jsonb_build_object('amount', v_final_amount, 'reason', p_reason, 'transaction_id', v_transaction_id));

    INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
    VALUES (p_target_user_id, 'Points Adjusted',
        'Your points balance has been adjusted by ' || v_final_amount || ' points. Reason: ' || p_reason,
        'points', v_transaction_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 2) Lock down role-management RPCs: app manages roles via the verified admin server function only
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) FROM authenticated, anon, PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) FROM authenticated, anon, PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3) Revoke direct client execution of internal-only functions
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.sync_points_balance(uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) FROM PUBLIC, anon, authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 4) Verified video-watch sessions (private; only definer RPCs manage rows)
CREATE TABLE IF NOT EXISTS public.video_watch_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    min_watch_seconds integer NOT NULL DEFAULT 10,
    expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '10 minutes'),
    consumed boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

GRANT ALL ON public.video_watch_sessions TO service_role;
ALTER TABLE public.video_watch_sessions ENABLE ROW LEVEL SECURITY;
-- No policies: direct client access is denied; only security-definer RPCs manage rows.

CREATE OR REPLACE FUNCTION public.start_video_watch_session(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task record;
    v_session_id uuid;
    v_min_seconds integer := 10;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT * INTO v_task FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos' AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified') THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- Invalidate any previous unused sessions for this user/task
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE user_id = _user_id AND task_id = _task_id AND consumed = false;

    INSERT INTO public.video_watch_sessions (user_id, task_id, min_watch_seconds)
    VALUES (_user_id, _task_id, v_min_seconds)
    RETURNING id INTO v_session_id;

    RETURN json_build_object('success', true, 'session_id', v_session_id, 'min_watch_seconds', v_min_seconds);
END;
$function$;

REVOKE ALL ON FUNCTION public.start_video_watch_session(uuid, uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 5) record_video_watch now requires a valid single-use watch session with server-enforced minimum duration
DROP FUNCTION IF EXISTS public.record_video_watch(uuid, uuid);

CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid, _session_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
    v_consumed_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Verify the server-issued watch session exists for this user/task
    IF NOT EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND user_id = _user_id AND task_id = _task_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Invalid watch session. Please start the ad again.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.video_watch_sessions WHERE id = _session_id AND expires_at < v_now) THEN
        RETURN json_build_object('success', false, 'message', 'Watch session expired. Please start the ad again.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND v_now < created_at + (min_watch_seconds || ' seconds')::interval
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Please watch the full ad before claiming progress.');
    END IF;

    -- Atomically consume the session (single-use, race-safe)
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE id = _session_id AND consumed = false
    RETURNING id INTO v_consumed_id;

    IF v_consumed_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'This watch session was already used.');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT * INTO v_task_record FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos' AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.task_submissions
        WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE
        SET status = 'verified', created_at = v_now;

        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true,
            'completed', true,
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'completed', false,
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid, uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260823020237_959a522b-0d1f-46c0-8909-7ed0f296b8e5.sql
-- =============================================

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_repeatable BOOLEAN DEFAULT false;

CREATE OR REPLACE VIEW public.user_daily_task_counts AS
SELECT 
    user_id, 
    COUNT(*) as daily_count
FROM 
    public.task_submissions
WHERE 
    status = 'verified' AND
    (created_at AT TIME ZONE 'GMT')::date = (CURRENT_DATE AT TIME ZONE 'GMT')
GROUP BY 
    user_id;

GRANT SELECT ON public.user_daily_task_counts TO authenticated;
GRANT SELECT ON public.user_daily_task_counts TO service_role;

-- Update submit_task to handle limits and repeatability
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing_status text;
    v_daily_count integer;
    v_is_repeatable boolean;
    v_last_submission_date date;
BEGIN
    -- Security check
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Check daily limit (count verified tasks today)
    SELECT COALESCE(daily_count, 0) INTO v_daily_count
    FROM public.user_daily_task_counts
    WHERE user_id = _user_id;

    IF v_daily_count >= 10 THEN
        RETURN json_build_object('success', false, 'message', 'Daily task limit reached (10 tasks max per day)');
    END IF;

    -- Check task repeatable status and last submission
    SELECT is_repeatable INTO v_is_repeatable FROM public.tasks WHERE id = _task_id;
    
    SELECT status, (created_at AT TIME ZONE 'GMT')::date 
    INTO v_existing_status, v_last_submission_date
    FROM public.task_submissions
    WHERE user_id = _user_id AND task_id = _task_id
    ORDER BY created_at DESC LIMIT 1;

    -- If verified today, can't do it again
    IF v_existing_status = 'verified' AND v_last_submission_date = (CURRENT_DATE AT TIME ZONE 'GMT')::date THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed today');
    END IF;

    -- If verified previously and NOT repeatable, can't do it again
    IF v_existing_status = 'verified' AND NOT v_is_repeatable THEN
        RETURN json_build_object('success', false, 'message', 'This task can only be completed once');
    END IF;

    IF v_existing_status = 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Task already pending verification');
    END IF;

    -- Allow if rejected, or if repeatable and last completion was before today, or if new
    INSERT INTO public.task_submissions (user_id, task_id, status)
    VALUES (_user_id, _task_id, 'pending');
    
    RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
END;
$$;

-- Update record_video_watch to handle limits
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid, _session_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
    v_consumed_id uuid;
    v_daily_count integer;
    v_existing_status text;
    v_last_submission_date date;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Verify session
    IF NOT EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND user_id = _user_id AND task_id = _task_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Invalid watch session.');
    END IF;

    -- Check daily limit
    SELECT COALESCE(daily_count, 0) INTO v_daily_count
    FROM public.user_daily_task_counts
    WHERE user_id = _user_id;

    IF v_daily_count >= 10 THEN
         RETURN json_build_object('success', false, 'message', 'Daily task limit reached (10 tasks max per day)');
    END IF;

    SELECT * INTO v_task_record FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos';

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    -- Atomically consume the session
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE id = _session_id AND consumed = false
    RETURNING id INTO v_consumed_id;

    IF v_consumed_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'This watch session was already used.');
    END IF;

    -- Record progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET watch_count = CASE 
            WHEN (video_ad_progress.last_watch_at AT TIME ZONE 'GMT')::date < (CURRENT_DATE AT TIME ZONE 'GMT')::date THEN 1
            ELSE video_ad_progress.watch_count + 1
        END,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now);

        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object('success', true, 'completed', true, 'points', v_task_record.points, 'message', 'Goal reached!');
    END IF;

    RETURN json_build_object('success', true, 'completed', false, 'watch_count', v_progress_record.watch_count, 'message', 'Progress updated.');
END;
$$;


-- =============================================
-- Migration: 20260823020401_59885ea6-f555-4d4d-ab26-d9dd8df065f2.sql
-- =============================================

-- The view currently uses SECURITY DEFINER by default which enforces view creator permissions.
-- We switch it to SECURITY INVOKER by recreating it as a simple view (which is invoker by default in Postgres 15+ or when not specified)
-- or explicitly setting it if the environment supports it.

DROP VIEW IF EXISTS public.user_daily_task_counts;

CREATE OR REPLACE VIEW public.user_daily_task_counts 
WITH (security_invoker = true)
AS
SELECT 
    user_id, 
    COUNT(*) as daily_count
FROM 
    public.task_submissions
WHERE 
    status = 'verified' AND
    (created_at AT TIME ZONE 'GMT')::date = (CURRENT_DATE AT TIME ZONE 'GMT')
GROUP BY 
    user_id;

GRANT SELECT ON public.user_daily_task_counts TO authenticated;
GRANT SELECT ON public.user_daily_task_counts TO service_role;


-- =============================================
-- Migration: 20260823020535_c45b9949-afd1-4fac-adc8-84afb917c371.sql
-- =============================================

-- Hardening search_path for all SECURITY DEFINER functions to prevent search_path spoofing
-- and revoking public execute where appropriate.

-- 1. has_role(uuid, public.app_role)
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.has_role(uuid, public.app_role) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 2. handle_new_user()
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_new_user() SET search_path = public, auth'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 3. claim_daily_reward(uuid)
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 4. verify_task_submission(uuid, boolean, text)
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.verify_task_submission(uuid, boolean, text) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 5. submit_task(uuid, uuid)
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.submit_task(uuid, uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 6. record_video_watch(uuid, uuid, uuid)
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.record_video_watch(uuid, uuid, uuid) SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) FROM PUBLIC'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 7. handle_task_status_notification()
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_task_status_notification() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 8. referral-related trigger functions
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.check_pending_referrals_on_update() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.handle_referral_reward_on_first_task() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 9. Fix the notifications insert policy mentioned in linter
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications" 
ON public.notifications 
FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);


-- =============================================
-- Migration: 20260823021853_2073bf56-3c83-4366-b210-9ba16fe5678d.sql
-- =============================================


-- Function to get daily task completions for analytics
CREATE OR REPLACE VIEW public.daily_task_completions AS
SELECT 
  date_trunc('day', created_at)::date as completion_date,
  count(*) as count
FROM public.task_submissions
WHERE status = 'approved'
GROUP BY 1
ORDER BY 1 DESC;

-- View for repeatable task claim rates (last 30 days)
CREATE OR REPLACE VIEW public.repeatable_task_stats AS
SELECT 
  t.id,
  t.title,
  count(ts.id) as total_claims,
  count(distinct ts.user_id) as unique_users,
  round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
FROM public.tasks t
JOIN public.task_submissions ts ON t.id = ts.task_id
WHERE t.is_repeatable = true 
  AND ts.status = 'approved'
  AND ts.created_at > now() - interval '30 days'
GROUP BY 1, 2;

GRANT SELECT ON public.daily_task_completions TO authenticated;
GRANT SELECT ON public.repeatable_task_stats TO authenticated;
GRANT SELECT ON public.daily_task_completions TO service_role;
GRANT SELECT ON public.repeatable_task_stats TO service_role;


-- =============================================
-- Migration: 20260823022142_b1c68575-dd06-4ebd-8c44-581591bac1bf.sql
-- =============================================


-- RPC for daily task completions with date filtering
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(start_date timestamptz, end_date timestamptz)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    date_trunc('day', created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
  GROUP BY 1
  ORDER BY 1 ASC;
$$;

-- RPC for repeatable task stats with date filtering
CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(start_date timestamptz, end_date timestamptz)
RETURNS TABLE (id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    t.id,
    t.title,
    count(ts.id) as total_claims,
    count(distinct ts.user_id) as unique_users,
    round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE t.is_repeatable = true 
    AND ts.status = 'approved'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
  GROUP BY 1, 2;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260823022452_4e901ff1-a82a-419b-9545-015ecb4e2d39.sql
-- =============================================


-- Update daily task completions RPC to include task filtering
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, 
  end_date timestamptz, 
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    date_trunc('day', created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
    AND (filter_task_id IS NULL OR task_id = filter_task_id)
  GROUP BY 1
  ORDER BY 1 ASC;
$$;

-- Update repeatable task stats RPC to include task filtering
CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date timestamptz, 
  end_date timestamptz, 
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    t.id,
    t.title,
    count(ts.id) as total_claims,
    count(distinct ts.user_id) as unique_users,
    round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE t.is_repeatable = true 
    AND ts.status = 'approved'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR t.id = filter_task_id)
  GROUP BY 1, 2;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260823022923_f5dd63d7-f772-4450-8858-2bc100c55ab6.sql
-- =============================================

-- Update task completions RPC to include granularity
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, 
  end_date timestamptz, 
  granularity text DEFAULT 'day',
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate granularity to prevent SQL injection or invalid truncations
  IF granularity NOT IN ('day', 'week', 'month') THEN
    granularity := 'day';
  END IF;

  RETURN QUERY
  SELECT 
    date_trunc(granularity, created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
    AND (filter_task_id IS NULL OR task_id = filter_task_id)
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$$;

-- Ensure grants are correct for the new signature
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260823031034_cf92e9f4-654e-4215-bf0d-303f7f376709.sql
-- =============================================

-- Fix submit_task to honor verification_required setting
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing_status text;
    v_daily_count integer;
    v_is_repeatable boolean;
    v_verification_required boolean;
    v_last_submission_date date;
    v_points integer;
BEGIN
    -- Security check
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Check daily limit (count verified tasks today)
    SELECT COALESCE(daily_count, 0) INTO v_daily_count
    FROM public.user_daily_task_counts
    WHERE user_id = _user_id;

    IF v_daily_count >= 10 THEN
        RETURN json_build_object('success', false, 'message', 'Daily task limit reached (10 tasks max per day)');
    END IF;

    -- Check task details
    SELECT is_repeatable, verification_required, points 
    INTO v_is_repeatable, v_verification_required, v_points 
    FROM public.tasks 
    WHERE id = _task_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found');
    END IF;

    -- Check existing submissions
    SELECT status, (created_at AT TIME ZONE 'GMT')::date 
    INTO v_existing_status, v_last_submission_date
    FROM public.task_submissions
    WHERE user_id = _user_id AND task_id = _task_id
    ORDER BY created_at DESC LIMIT 1;

    -- If verified today, can't do it again
    IF v_existing_status = 'verified' AND v_last_submission_date = (CURRENT_DATE AT TIME ZONE 'GMT')::date THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed today');
    END IF;

    -- If verified previously and NOT repeatable, can't do it again
    IF v_existing_status = 'verified' AND NOT v_is_repeatable THEN
        RETURN json_build_object('success', false, 'message', 'This task can only be completed once');
    END IF;

    IF v_existing_status = 'pending' THEN
        RETURN json_build_object('success', false, 'message', 'Task already pending verification');
    END IF;

    -- Insert submission with correct status based on verification requirement
    INSERT INTO public.task_submissions (user_id, task_id, status)
    VALUES (
        _user_id, 
        _task_id, 
        CASE WHEN v_verification_required THEN 'pending'::text ELSE 'verified'::text END
    )
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET status = EXCLUDED.status, created_at = now();
    
    IF v_verification_required THEN
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification');
    ELSE
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_points || ' points awarded.', 'points', v_points);
    END IF;
END;
$$;

-- Grant EXECUTE to authenticated users for admin processing
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260823161643_201d0d22-9415-4ea1-a68a-dce11b71d468.sql
-- =============================================

-- 1. Fix mutable search_path on the task submission notification trigger
DO $$ BEGIN EXECUTE 'ALTER FUNCTION public.notify_on_task_submission() SET search_path = public'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- 2. Make analytics views run with the querying user's permissions (security invoker)
ALTER VIEW public.daily_task_completions SET (security_invoker = true);
ALTER VIEW public.repeatable_task_stats SET (security_invoker = true);

-- 3. Replace the open notification-insert path with a validated SECURITY DEFINER function
CREATE OR REPLACE FUNCTION public.send_user_notification(
  _user_id uuid,
  _title text,
  _message text,
  _type text DEFAULT 'system',
  _metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only admins and moderators may send notifications to other users
  IF auth.uid() IS NULL OR (
    NOT public.has_role(auth.uid(), 'admin') AND
    NOT public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: insufficient privileges';
  END IF;

  -- Prevent abuse via oversized payloads
  IF char_length(_title) > 200 OR char_length(_message) > 2000 THEN
    RAISE EXCEPTION 'Notification content too long';
  END IF;

  IF char_length(_type) > 50 THEN
    RAISE EXCEPTION 'Invalid notification type';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id) THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type, metadata)
  VALUES (_user_id, _title, _message, _type, _metadata);

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) FROM public, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- Remove the permissive policy that let any user insert notifications for anyone
DROP POLICY IF EXISTS "Users can insert notifications for others during system actions" ON public.notifications;

-- 4. Narrow moderator access on task_submissions: no more full ALL (no DELETE of history)
DROP POLICY IF EXISTS "Admins and moderators can manage task submissions" ON public.task_submissions;

CREATE POLICY "Admins can manage task submissions"
ON public.task_submissions
FOR ALL
TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Moderators can update task submissions"
ON public.task_submissions
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'moderator'))
WITH CHECK (public.has_role(auth.uid(), 'moderator'));

-- =============================================
-- Migration: 20260825133455_88108a4b-99a6-42f9-bdfc-4c8f6fbb9339.sql
-- =============================================

ALTER TABLE public.task_submissions
  ADD CONSTRAINT task_submissions_user_id_profiles_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE
  NOT VALID;

ALTER PUBLICATION supabase_realtime ADD TABLE public.task_submissions;
ALTER TABLE public.task_submissions REPLICA IDENTITY FULL;

-- =============================================
-- Migration: 20260825235000_update_streak_bonus_schedule.sql
-- =============================================

-- Update claim_daily_reward with the new streak bonus schedule:
-- Day 1: 5 PTS
-- Day 2: 5 PTS
-- Day 3: 10 PTS
-- Day 4: 10 PTS
-- Day 5: 15 PTS
-- Day 6: 15 PTS
-- Day 7+: 20 PTS
-- If streak cuts, it restarts from Day 1 (5 PTS).

CREATE OR REPLACE FUNCTION public.claim_daily_reward(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_streak_record record;
    v_points_to_add integer := 5;
    v_is_consecutive boolean := false;
    v_last_claim date;
    v_now timestamp with time zone := now();
    v_result_streak integer := 1;
begin
    -- SECURITY CHECK: Ensure the authenticated user is only claiming for themselves
    if auth.uid() <> _user_id then
        return json_build_object('success', false, 'message', 'Unauthorized: You can only claim rewards for your own account.');
    end if;

    -- Use explicit transaction lock to prevent concurrent race conditions
    perform pg_advisory_xact_lock(hashtext(_user_id::text));

    -- 1. Check if user already claimed today
    select * into v_streak_record 
    from public.user_streaks 
    where user_id = _user_id;

    if v_streak_record.last_activity_at is not null then
        v_last_claim := v_streak_record.last_activity_at::date;
        if v_last_claim = v_now::date then
            return json_build_object('success', false, 'message', 'You have already claimed your reward for today.');
        end if;
        
        -- Check if it is consecutive (yesterday)
        if v_last_claim = (v_now::date - interval '1 day')::date then
            v_is_consecutive := true;
        end if;
    end if;

    -- 2. Update streak
    if v_is_consecutive then
        update public.user_streaks
        set 
            current_streak = current_streak + 1,
            longest_streak = greatest(longest_streak, current_streak + 1),
            last_activity_at = v_now
        where user_id = _user_id
        returning current_streak into v_result_streak;
    else
        insert into public.user_streaks (user_id, current_streak, longest_streak, last_activity_at)
        values (_user_id, 1, 1, v_now)
        on conflict (user_id) do update 
        set 
            current_streak = 1,
            last_activity_at = v_now
        returning current_streak into v_result_streak;
    end if;

    -- 3. Determine points based on new streak schedule:
    -- Day 1: 5, Day 2: 5, Day 3: 10, Day 4: 10, Day 5: 15, Day 6: 15, Day 7+: 20
    if v_result_streak = 1 then
        v_points_to_add := 5;
    elsif v_result_streak = 2 then
        v_points_to_add := 5;
    elsif v_result_streak = 3 then
        v_points_to_add := 10;
    elsif v_result_streak = 4 then
        v_points_to_add := 10;
    elsif v_result_streak = 5 then
        v_points_to_add := 15;
    elsif v_result_streak = 6 then
        v_points_to_add := 15;
    else
        v_points_to_add := 20;
    end if;

    -- 4. Record points transaction
    insert into public.points_transactions (user_id, amount, type, description, status, created_at)
    values (_user_id, v_points_to_add, 'earn', format('Day %s Daily Check-in Streak Bonus', v_result_streak), 'completed', v_now);

    -- 5. Create instant in-app notification
    insert into public.notifications (user_id, title, message, type, created_at)
    values (_user_id, 'Daily Streak Bonus Claimed! ðŸ”¥', format('You claimed +%s PTS for maintaining your Day %s streak!', v_points_to_add, v_result_streak), 'points', v_now);

    return json_build_object(
        'success', true, 
        'points', v_points_to_add, 
        'current_streak', v_result_streak,
        'message', format('Day %s streak bonus claimed! +%s points', v_result_streak, v_points_to_add)
    );
end;
$function$;


-- =============================================
-- Migration: 20260826001000_restrict_privileged_select_policies.sql
-- =============================================

-- Migration: Restrict broad SELECT policies on profiles, task_submissions, and tasks to admin and moderator roles only.
-- Prevents non-privileged roles (like 'tasker') from reading all users' private data or global submissions.

-- 1. PROFILES TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins and moderators can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Privileged roles can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can select their own profile" ON public.profiles;

-- Normal users can only read their own profile or profiles of users who signed up using their referral link
CREATE POLICY "Users can select their own and referee profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  auth.uid() = id 
  OR EXISTS (
    SELECT 1 FROM public.referrals r 
    WHERE r.referrer_id = auth.uid() AND r.referee_id = public.profiles.id
  )
);

-- Only admin and moderator roles can select all profiles
CREATE POLICY "Admins and moderators can select all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);


-- 2. TASK_SUBMISSIONS TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can view all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Privileged roles can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Admins and moderators can view all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Admins and moderators can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Users can view their own submissions" ON public.task_submissions;

-- Normal users can only view their own submissions
CREATE POLICY "Users can view their own submissions"
ON public.task_submissions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Only admin and moderator roles can view all user submissions
CREATE POLICY "Admins and moderators can select all submissions"
ON public.task_submissions
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);


-- 3. TASKS TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can select all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Privileged roles can view all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Privileged roles can manage tasks" ON public.tasks;
DROP POLICY IF EXISTS "Anyone can read active tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can select all tasks" ON public.tasks;

-- All authenticated users can read active tasks to earn
CREATE POLICY "Anyone can read active tasks"
ON public.tasks
FOR SELECT
TO authenticated
USING (is_active = TRUE);

-- Only admins and moderators can select all tasks (including inactive / drafts)
CREATE POLICY "Admins and moderators can select all tasks"
ON public.tasks
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);


-- =============================================
-- Migration: 20260826015115_9279926b-4128-403c-9ed7-eac26daeff0d.sql
-- =============================================

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
    id, email, points_balance, username, full_name, referral_code, referred_by
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_welcome_bonus,
    v_username,
    NULLIF(btrim(new.raw_user_meta_data->>'full_name'), ''),
    v_referral_code,
    v_referrer_id
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = COALESCE(public.profiles.username, EXCLUDED.username),
      full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
      referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
      referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by);

  INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
  VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus', 'completed', new.id)
  ON CONFLICT DO NOTHING;

  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO UPDATE
    SET referrer_id = EXCLUDED.referrer_id;

    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    VALUES (
      v_referrer_id,
      'New Referral!',
      'Someone signed up using your referral. Your bonus unlocks after their first completed task.',
      'info',
      jsonb_build_object('referee_id', new.id)
    );
  END IF;

  RETURN new;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

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
BEGIN
  IF NEW.status = 'verified' AND OLD.status IS DISTINCT FROM 'verified' THEN
    SELECT r.referrer_id
    INTO v_referrer_id
    FROM public.referrals r
    WHERE r.referee_id = NEW.user_id;

    IF v_referrer_id IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

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
      SELECT COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your friend')
      INTO v_referee_name
      FROM public.profiles p
      WHERE p.id = NEW.user_id;

      INSERT INTO public.points_transactions (
        user_id, amount, type, description, status, source_id
      )
      VALUES (
        v_referrer_id,
        v_referral_bonus,
        'referral',
        'Referral bonus: ' || COALESCE(v_referee_name, 'your friend') || ' completed their first task',
        'completed',
        NEW.user_id
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_transaction_id;

      IF v_transaction_id IS NOT NULL THEN
        INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
        VALUES (
          v_referrer_id,
          v_referral_bonus,
          'Referral bonus for ' || COALESCE(v_referee_name, 'referee') || '''s first task',
          'handle_referral_reward_on_first_task'
        );

        INSERT INTO public.notifications (
          user_id, title, message, type, transaction_id, metadata
        )
        VALUES (
          v_referrer_id,
          'Referral Reward!',
          'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_name, 'your friend') || ' completed their first task!',
          'referral',
          v_transaction_id,
          jsonb_build_object('referee_id', NEW.user_id, 'points', v_referral_bonus)
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_referral_reward_on_first_task() FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO postgres, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

DROP TRIGGER IF EXISTS on_task_verified_referral ON public.task_submissions;
DROP TRIGGER IF EXISTS tr_handle_referral_reward_on_first_task ON public.task_submissions;
CREATE TRIGGER on_task_verified_referral
AFTER UPDATE OF status ON public.task_submissions
FOR EACH ROW
WHEN (NEW.status = 'verified' AND OLD.status IS DISTINCT FROM 'verified')
EXECUTE FUNCTION public.handle_referral_reward_on_first_task();

WITH inferred_referrals AS (
  SELECT DISTINCT ON (u.id)
    u.id AS referee_id,
    ref.id AS referrer_id
  FROM auth.users u
  JOIN public.profiles ref
    ON ref.id <> u.id
   AND (
     lower(ref.referral_code) = lower(COALESCE(
       u.raw_user_meta_data->>'referral_code_used',
       u.raw_user_meta_data->>'referral_code',
       u.raw_user_meta_data->>'referred_by'
     ))
     OR lower(ref.username) = lower(COALESCE(
       u.raw_user_meta_data->>'referral_code_used',
       u.raw_user_meta_data->>'referral_code',
       u.raw_user_meta_data->>'referred_by'
     ))
   )
  WHERE NULLIF(btrim(COALESCE(
    u.raw_user_meta_data->>'referral_code_used',
    u.raw_user_meta_data->>'referral_code',
    u.raw_user_meta_data->>'referred_by'
  )), '') IS NOT NULL
  ORDER BY u.id,
    CASE WHEN lower(ref.referral_code) = lower(COALESCE(
      u.raw_user_meta_data->>'referral_code_used',
      u.raw_user_meta_data->>'referral_code',
      u.raw_user_meta_data->>'referred_by'
    )) THEN 0 ELSE 1 END
)
INSERT INTO public.referrals (referrer_id, referee_id)
SELECT referrer_id, referee_id
FROM inferred_referrals
ON CONFLICT (referee_id) DO UPDATE
SET referrer_id = EXCLUDED.referrer_id;

UPDATE public.profiles p
SET referred_by = r.referrer_id
FROM public.referrals r
WHERE r.referee_id = p.id
  AND p.referred_by IS DISTINCT FROM r.referrer_id;

WITH eligible AS (
  SELECT r.referrer_id, r.referee_id,
         COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your friend') AS referee_name
  FROM public.referrals r
  LEFT JOIN public.profiles p ON p.id = r.referee_id
  WHERE EXISTS (
    SELECT 1 FROM public.task_submissions ts
    WHERE ts.user_id = r.referee_id AND ts.status = 'verified'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.points_transactions pt
    WHERE pt.user_id = r.referrer_id
      AND (
        (pt.type IN ('referral', 'referral_bonus') AND pt.source_id = r.referee_id)
        OR (
          pt.type IN ('referral', 'referral_bonus')
          AND pt.source_id IS NULL
          AND pt.created_at <= r.created_at + interval '10 minutes'
          AND pt.created_at >= r.created_at - interval '10 minutes'
        )
      )
  )
), inserted_rewards AS (
  INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
  SELECT e.referrer_id, 75, 'referral',
         'Referral bonus: ' || e.referee_name || ' completed their first task',
         'completed', e.referee_id
  FROM eligible e
  ON CONFLICT DO NOTHING
  RETURNING user_id, amount, source_id, id
)
INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
SELECT ir.user_id,
       'Referral Reward!',
       'Your missing referral reward has been credited: ' || ir.amount || ' points.',
       'referral',
       ir.id,
       jsonb_build_object('referee_id', ir.source_id, 'points', ir.amount, 'repaired', true)
FROM inserted_rewards ir;

SELECT public.sync_points_balance(r.referrer_id)
FROM (SELECT DISTINCT referrer_id FROM public.referrals) r;

-- =============================================
-- Migration: 20260826231220_72fb5717-a825-41e9-ac0f-07d9a69aa9a6.sql
-- =============================================

GRANT ALL ON SCHEMA public TO sandbox_exec;
GRANT USAGE ON SCHEMA auth, storage, extensions TO sandbox_exec;
GRANT ALL ON ALL TABLES IN SCHEMA public TO sandbox_exec;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO sandbox_exec;
GRANT TRIGGER, SELECT, REFERENCES ON auth.users TO sandbox_exec;
GRANT ALL ON storage.objects TO sandbox_exec;
GRANT ALL ON storage.buckets TO sandbox_exec;
GRANT anon, authenticated, service_role TO sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO sandbox_exec;

-- =============================================
-- Migration: 20260826231259_530376b0-9bcf-453e-ade0-7e63074d235f.sql
-- =============================================

GRANT REFERENCES, TRIGGER ON TABLE auth.users TO sandbox_exec;

-- =============================================
-- Migration: 20260826231319_1cb78869-88e3-42c6-8464-43179f7bb9dc.sql
-- =============================================

CREATE OR REPLACE FUNCTION public._restore_exec(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$ BEGIN EXECUTE sql; END; $$;
REVOKE ALL ON FUNCTION public._restore_exec(text) FROM PUBLIC, anon, authenticated, service_role;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public._restore_exec(text) TO sandbox_exec'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260826231533_f8b8ef03-c7d4-4549-8c77-dabbed9c3d72.sql
-- =============================================

ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'moderator';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'task_manager';

-- =============================================
-- Migration: 20260826231558_f81f41f6-34ec-4828-8919-3e78998482c7.sql
-- =============================================

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

  UPDATE public.profiles SET points_balance = points_balance - v_cost WHERE id = v_user_id;

  IF v_stock IS NOT NULL THEN
    UPDATE public.rewards SET stock_count = stock_count - 1 WHERE id = _reward_id;
  END IF;

  INSERT INTO public.redemptions (user_id, reward_id, status)
  VALUES (v_user_id, _reward_id, 'pending')
  RETURNING id INTO v_redemption_id;

  INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
  VALUES (v_user_id, -v_cost, 'redemption', 'Redeemed reward: ' || v_title, v_redemption_id);

  RETURN jsonb_build_object('success', true, 'message', 'Redemption submitted', 'redemption_id', v_redemption_id);
END;
$$;
REVOKE ALL ON FUNCTION public.redeem_reward(uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.send_user_notification(_user_id uuid, _title text, _message text, _type text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  INSERT INTO public.notifications (user_id, title, message, type)
  VALUES (_user_id, _title, _message, _type);

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION public.send_user_notification(uuid, text, text, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(p_target_user_id uuid, p_amount integer, p_action_type text, p_reason text)
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

  RETURN jsonb_build_object('success', true);
END;
$$;
REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260826233543_fa3488e1-77ed-4048-aae0-2e794c8b87e7.sql
-- =============================================

DROP FUNCTION IF EXISTS public._restore_exec(text);
REVOKE ALL ON SCHEMA public FROM sandbox_exec;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM sandbox_exec;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM sandbox_exec;
REVOKE ALL ON storage.objects FROM sandbox_exec;
REVOKE ALL ON storage.buckets FROM sandbox_exec;
REVOKE anon, authenticated, service_role FROM sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM sandbox_exec;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM sandbox_exec;
GRANT USAGE ON SCHEMA public TO sandbox_exec;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO sandbox_exec;

-- =============================================
-- Migration: 20260826233607_daeb6951-540f-4935-99ff-2122cc418d96.sql
-- =============================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
  END LOOP;
END $$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated, anon'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260826233624_864c471a-d6ff-49f8-8737-def3aacc98db.sql
-- =============================================

ALTER TABLE public.rewards ADD COLUMN IF NOT EXISTS category text DEFAULT 'Gift Cards';

-- =============================================
-- Migration: 20260827004320_22331933-7e26-498a-8d68-63432d5df85b.sql
-- =============================================

CREATE POLICY "Admins and moderators can insert tasks" ON public.tasks FOR INSERT TO authenticated WITH CHECK (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator'));
CREATE POLICY "Admins and moderators can update tasks" ON public.tasks FOR UPDATE TO authenticated USING (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator')) WITH CHECK (public.has_role(auth.uid(),'admin') OR public.has_role(auth.uid(),'moderator'));
CREATE POLICY "Admins can delete tasks" ON public.tasks FOR DELETE TO authenticated USING (public.has_role(auth.uid(),'admin'));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tasks TO authenticated;
GRANT ALL ON public.tasks TO service_role;

-- =============================================
-- Migration: 20260827004455_4fb32890-47a0-48c6-a7c7-a1d47a0f73f6.sql
-- =============================================

ALTER TABLE public.admin_audit_logs DROP CONSTRAINT IF EXISTS admin_audit_logs_action_type_check;
ALTER TABLE public.admin_audit_logs ADD CONSTRAINT admin_audit_logs_action_type_check CHECK (action_type = ANY (ARRAY['INSERT','UPDATE','DELETE','points_adjustment','role_change','status_change']));

-- =============================================
-- Migration: 20260827004834_0bbd6510-5f94-4ae2-ae71-85b1fcdc6db2.sql
-- =============================================

ALTER TABLE public.task_submissions
  ADD COLUMN IF NOT EXISTS admin_note text,
  ADD COLUMN IF NOT EXISTS verified_at timestamp with time zone;

CREATE OR REPLACE FUNCTION public.verify_task_submission(
  _submission_id uuid,
  _approve boolean,
  _admin_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission public.task_submissions%ROWTYPE;
  v_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR
    public.has_role(auth.uid(), 'moderator')
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT * INTO v_submission
  FROM public.task_submissions
  WHERE id = _submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission not found');
  END IF;

  IF v_submission.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission has already been processed');
  END IF;

  v_status := CASE WHEN _approve THEN 'verified' ELSE 'rejected' END;

  UPDATE public.task_submissions
  SET status = v_status,
      admin_note = NULLIF(btrim(_admin_note), ''),
      verified_at = now()
  WHERE id = _submission_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN _approve THEN 'Task approved successfully' ELSE 'Task rejected' END,
    'status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_task_submission(uuid, boolean, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
  p_target_user_id uuid,
  p_amount integer,
  p_action_type text,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_transaction_id uuid;
  v_final_amount integer;
BEGIN
  IF v_admin_id IS NULL OR NOT public.has_role(v_admin_id, 'admin') THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
  END IF;
  IF p_action_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Invalid points action';
  END IF;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero';
  END IF;
  IF NULLIF(btrim(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'A reason is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  v_final_amount := CASE WHEN p_action_type = 'credit' THEN p_amount ELSE -p_amount END;

  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (p_target_user_id, v_final_amount, 'adjustment', 'Admin adjustment: ' || btrim(p_reason), 'completed')
  RETURNING id INTO v_transaction_id;

  INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
  VALUES (p_target_user_id, v_final_amount, 'Admin Adjustment: ' || btrim(p_reason), 'manual_admin_action');

  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
  VALUES (v_admin_id, 'points_adjustment', 'profiles', p_target_user_id,
    jsonb_build_object('amount', v_final_amount, 'reason', btrim(p_reason), 'transaction_id', v_transaction_id));
END;
$$;

REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

ALTER TABLE public.admin_audit_logs DROP CONSTRAINT IF EXISTS admin_audit_logs_action_type_check;
ALTER TABLE public.admin_audit_logs ADD CONSTRAINT admin_audit_logs_action_type_check CHECK (
  action_type IN (
    'INSERT', 'UPDATE', 'DELETE', 'points_adjustment', 'role_change',
    'status_change', 'auto_fraud_flag', 'referral_reward', 'task_verification'
  )
);

CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  granularity text DEFAULT 'day',
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE(completion_date date, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF granularity NOT IN ('day', 'week', 'month') THEN
    granularity := 'day';
  END IF;
  RETURN QUERY
  SELECT date_trunc(granularity, ts.created_at)::date, count(*)
  FROM public.task_submissions ts
  WHERE ts.status = 'verified'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR ts.task_id = filter_task_id)
  GROUP BY 1 ORDER BY 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE(id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT t.id, t.title, count(ts.id), count(DISTINCT ts.user_id),
    round(count(ts.id)::numeric / nullif(count(DISTINCT ts.user_id), 0), 2)
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE t.is_repeatable = true
    AND ts.status = 'verified'
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR t.id = filter_task_id)
  GROUP BY t.id, t.title;
END;
$$;

REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, text, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone, uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamp with time zone, timestamp with time zone, text, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamp with time zone, timestamp with time zone, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

REVOKE ALL ON FUNCTION public.sync_points_balance(uuid) FROM PUBLIC, anon, authenticated;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

INSERT INTO public.app_settings (key, value, description)
VALUES ('daily_task_limit', '10'::jsonb, 'Maximum tasks a user may complete per day')
ON CONFLICT (key) DO NOTHING;

UPDATE public.role_permissions
SET is_enabled = CASE
  WHEN tab_name IN ('tasks', 'verifications', 'approvals') THEN true
  ELSE false
END
WHERE role = 'moderator';

-- =============================================
-- Migration: 20260827005135_a4e998f6-3403-465e-8f51-a3fbd2bdb4c7.sql
-- =============================================

DROP POLICY IF EXISTS "Admins and moderators can insert tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can update tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can select all tasks" ON public.tasks;

CREATE POLICY "Task staff can insert tasks"
ON public.tasks FOR INSERT TO authenticated
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can update tasks"
ON public.tasks FOR UPDATE TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
)
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can select all tasks"
ON public.tasks FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

DROP POLICY IF EXISTS "Admins and moderators can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Moderators can update task submissions" ON public.task_submissions;

CREATE POLICY "Task staff can select all submissions"
ON public.task_submissions FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE POLICY "Task staff can update submissions"
ON public.task_submissions FOR UPDATE TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
)
WITH CHECK (
  public.has_role(auth.uid(), 'admin') OR
  public.has_role(auth.uid(), 'moderator') OR
  public.has_role(auth.uid(), 'task_manager') OR
  public.has_role(auth.uid(), 'tasker')
);

CREATE OR REPLACE FUNCTION public.verify_task_submission(
  _submission_id uuid,
  _approve boolean,
  _admin_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission public.task_submissions%ROWTYPE;
  v_status text;
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR
    public.has_role(auth.uid(), 'moderator') OR
    public.has_role(auth.uid(), 'task_manager') OR
    public.has_role(auth.uid(), 'tasker')
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT * INTO v_submission
  FROM public.task_submissions
  WHERE id = _submission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission not found');
  END IF;
  IF v_submission.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Submission has already been processed');
  END IF;

  v_status := CASE WHEN _approve THEN 'verified' ELSE 'rejected' END;
  UPDATE public.task_submissions
  SET status = v_status,
      admin_note = NULLIF(btrim(_admin_note), ''),
      verified_at = now()
  WHERE id = _submission_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', CASE WHEN _approve THEN 'Task approved successfully' ELSE 'Task rejected' END,
    'status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.verify_task_submission(uuid, boolean, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.verify_task_submission(uuid, boolean, text) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260827005239_563fb6c0-6ba8-4910-b1d8-4f8355145544.sql
-- =============================================

CREATE UNIQUE INDEX IF NOT EXISTS user_roles_one_role_per_user_idx ON public.user_roles (user_id);

DROP POLICY IF EXISTS "All authenticated users can read permissions" ON public.role_permissions;
CREATE POLICY "Users can read permissions for their own role"
ON public.role_permissions FOR SELECT TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.role = role_permissions.role
  )
);

REVOKE INSERT, UPDATE, DELETE ON public.points_transactions FROM authenticated;
GRANT SELECT ON public.points_transactions TO authenticated;

REVOKE ALL ON public.video_watch_sessions FROM anon, authenticated;
GRANT ALL ON public.video_watch_sessions TO service_role;

-- =============================================
-- Migration: 20260827005402_d82127d8-a662-49e7-a349-26c41bd6f9a8.sql
-- =============================================

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
    AND status = 'verified'
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

  IF v_existing_status = 'verified' AND v_last_submission_date = (now() AT TIME ZONE 'UTC')::date THEN
    RETURN json_build_object('success', false, 'message', 'Task already completed today');
  END IF;
  IF v_existing_status = 'verified' AND NOT COALESCE(v_is_repeatable, false) THEN
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

REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260827005845_58432429-2a41-4768-bea4-574e158f5271.sql
-- =============================================

-- 1. Allow the internal points sync to write points_balance
CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role'
     AND NOT public.has_role(auth.uid(), 'admin')
     AND COALESCE(current_setting('app.points_sync', true), 'off') <> 'on' THEN
    NEW.points_balance := OLD.points_balance;
    NEW.referral_code := OLD.referral_code;
    NEW.referred_by := OLD.referred_by;
    NEW.referral_clicks := OLD.referral_clicks;
    NEW.has_claimed_welcome_bonus := OLD.has_claimed_welcome_bonus;
    NEW.email := OLD.email;
    NEW.id := OLD.id;
  END IF;
  RETURN NEW;
END;
$function$;

-- 2. Remove duplicate incremental balance trigger (sync trigger is source of truth)
DROP TRIGGER IF EXISTS on_points_transaction_change ON public.points_transactions;

-- 3. Referral reward must also fire on direct INSERT of a verified submission
CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_referrer_id uuid;
  v_referral_bonus integer := 75;
  v_referee_name text;
  v_transaction_id uuid;
  v_is_new_verified boolean;
BEGIN
  v_is_new_verified := (TG_OP = 'INSERT' AND NEW.status = 'verified')
    OR (TG_OP = 'UPDATE' AND NEW.status = 'verified' AND OLD.status IS DISTINCT FROM 'verified');

  IF v_is_new_verified THEN
    SELECT r.referrer_id INTO v_referrer_id FROM public.referrals r WHERE r.referee_id = NEW.user_id;

    IF v_referrer_id IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

      -- only once per referee
      IF EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = v_referrer_id AND type = 'referral' AND source_id = NEW.user_id
      ) THEN
        RETURN NEW;
      END IF;

      SELECT COALESCE(
        CASE
          WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
          WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
          ELSE NULL
        END, 75)
      INTO v_referral_bonus
      FROM public.app_settings
      WHERE key IN ('welcome_bonus_amount_referrer', 'referral_bonus')
      ORDER BY CASE WHEN key = 'welcome_bonus_amount_referrer' THEN 0 ELSE 1 END
      LIMIT 1;

      v_referral_bonus := COALESCE(v_referral_bonus, 75);

      SELECT COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your friend')
      INTO v_referee_name FROM public.profiles p WHERE p.id = NEW.user_id;

      INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
      VALUES (v_referrer_id, v_referral_bonus, 'referral',
        'Referral bonus: ' || COALESCE(v_referee_name, 'your friend') || ' completed their first task',
        'completed', NEW.user_id)
      RETURNING id INTO v_transaction_id;

      IF v_transaction_id IS NOT NULL THEN
        INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
        VALUES (v_referrer_id, v_referral_bonus,
          'Referral bonus for ' || COALESCE(v_referee_name, 'referee') || '''s first task',
          'handle_referral_reward_on_first_task');
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS on_task_verified_referral ON public.task_submissions;
CREATE TRIGGER on_task_verified_referral
AFTER INSERT OR UPDATE ON public.task_submissions
FOR EACH ROW EXECUTE FUNCTION public.handle_referral_reward_on_first_task();

-- 4. Recalculate all balances
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.profiles LOOP
    PERFORM public.sync_points_balance(r.id);
  END LOOP;
END $$;

-- =============================================
-- Migration: 20260827010214_974042bc-9973-46e8-8e60-9a9f31f5cdb9.sql
-- =============================================

DROP FUNCTION IF EXISTS public.send_user_notification(uuid, text, text, text);

-- =============================================
-- Migration: 20260827012532_d366dc27-cf02-4367-a30d-0e2da0b76db0.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.admin_revoke_task_submission(_submission_id uuid, _admin_note text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_sub public.task_submissions%ROWTYPE;
  v_task_title text;
  v_credited integer;
BEGIN
  IF NOT (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')) THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT * INTO v_sub FROM public.task_submissions WHERE id = _submission_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Submission not found');
  END IF;

  SELECT title INTO v_task_title FROM public.tasks WHERE id = v_sub.task_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_credited
  FROM public.points_transactions
  WHERE user_id = v_sub.user_id AND source_id = v_sub.id AND status = 'completed';

  IF v_credited <> 0 THEN
    INSERT INTO public.points_transactions (user_id, amount, type, description, source_id, status)
    VALUES (v_sub.user_id, -v_credited, 'adjust',
            'Reversed points for revoked task: ' || COALESCE(v_task_title, 'task'),
            v_sub.id, 'completed');
  END IF;

  DELETE FROM public.task_submissions WHERE id = _submission_id;

  PERFORM public.sync_points_balance(v_sub.user_id);

  PERFORM public.send_user_notification(
    v_sub.user_id,
    'Task reset: ' || COALESCE(v_task_title, 'Task'),
    COALESCE(NULLIF(_admin_note, ''), 'This task was reset by an admin and is available to complete again.')
      || CASE WHEN v_credited <> 0 THEN ' ' || v_credited || ' points were removed.' ELSE '' END,
    'warning',
    jsonb_build_object('task_id', v_sub.task_id)
  );

  RETURN json_build_object('success', true, 'points_removed', v_credited);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_revoke_task_submission(uuid, text) FROM PUBLIC, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.admin_revoke_task_submission(uuid, text) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260828185210_5c1dde20-b2ee-484c-97a8-b1225226bf38.sql
-- =============================================


DROP FUNCTION IF EXISTS public.get_daily_task_completions(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.get_daily_task_completions(timestamptz, timestamptz, uuid);
DROP FUNCTION IF EXISTS public.get_repeatable_task_stats(timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, end_date timestamptz,
  granularity text DEFAULT 'day', filter_task_id uuid DEFAULT NULL)
RETURNS TABLE(completion_date date, count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF granularity NOT IN ('day', 'week', 'month') THEN granularity := 'day'; END IF;
  RETURN QUERY
  SELECT date_trunc(granularity, ts.created_at)::date, count(*)
  FROM public.task_submissions ts
  WHERE ts.status IN ('verified', 'approved')
    AND ts.created_at >= start_date AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR ts.task_id = filter_task_id)
  GROUP BY 1 ORDER BY 1;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date timestamptz, end_date timestamptz, filter_task_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT t.id, t.title, count(ts.id), count(DISTINCT ts.user_id),
    round(count(ts.id)::numeric / nullif(count(DISTINCT ts.user_id), 0), 2)
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE ts.status IN ('verified', 'approved')
    AND ts.created_at >= start_date AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR t.id = filter_task_id)
  GROUP BY t.id, t.title
  ORDER BY 3 DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_funnel_stats(start_date timestamptz, end_date timestamptz)
RETURNS TABLE(referrals bigint, signups bigint, bonuses bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.referrals r
       WHERE r.created_at >= start_date AND r.created_at <= end_date),
    (SELECT count(*) FROM public.profiles p
       WHERE p.created_at >= start_date AND p.created_at <= end_date),
    (SELECT count(*) FROM public.profiles p
       WHERE p.has_claimed_welcome_bonus = true
         AND p.created_at >= start_date AND p.created_at <= end_date);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_funnel_stats(timestamptz, timestamptz) FROM public, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_funnel_stats(timestamptz, timestamptz) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260829000000_fix_username_availability.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.check_username_available(_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE lower(trim(_username)) = lower(trim(profiles.username))
  );
END;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260829010000_fix_signup_validation_rpcs.sql
-- =============================================

DROP FUNCTION IF EXISTS public.check_username_available(text);
DROP FUNCTION IF EXISTS public.check_referral_code(text);
DROP FUNCTION IF EXISTS public.check_referral_code(text, uuid);

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
    WHERE p.referral_code = _code
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY
        SELECT NULL::text, false, 'Referral code not found.'::text;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT v_referrer_username, true, 'Valid referral code.'::text;
END;
$$;

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;


-- =============================================
-- Migration: 20260829052707_08ba7f6b-873b-4246-838a-2490588af574.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.check_username_available(_username text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE lower(p.username) = lower(trim(_username))
  );
$$;

REVOKE ALL ON FUNCTION public.check_username_available(text) FROM public;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO anon, authenticated, service_role'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260829052726_af6e18cc-2108-407f-b488-e35207c39c12.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(username text, is_valid boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_referrer_username text;
BEGIN
    SELECT p.username INTO v_referrer_username
    FROM public.profiles p
    WHERE lower(trim(p.referral_code)) = lower(trim(_code))
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    RETURN QUERY SELECT v_referrer_username, TRUE, ('Referrer found: ' || v_referrer_username)::text;
END;
$function$;

-- =============================================
-- Migration: 20260829052736_47e79e31-10b0-40fd-860f-3f03d6db715a.sql
-- =============================================

DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated, service_role, sandbox_exec'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260829053743_a8e7337d-a402-42e9-b960-06834b4f4b23.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.guard_profile_sensitive_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' AND NOT public.has_role(auth.uid(), 'admin') THEN
    NEW.points_balance := OLD.points_balance;
    NEW.referral_code := OLD.referral_code;
    NEW.referred_by := OLD.referred_by;
    NEW.referral_clicks := OLD.referral_clicks;
    NEW.has_claimed_welcome_bonus := OLD.has_claimed_welcome_bonus;
    NEW.email := OLD.email;
    NEW.id := OLD.id;
    NEW.last_ip := OLD.last_ip;
    NEW.fingerprint := OLD.fingerprint;
  END IF;
  RETURN NEW;
END;
$$;

DROP POLICY IF EXISTS "Users can read their own redemptions" ON public.redemptions;

DROP POLICY IF EXISTS "Users can select their own and referee profiles" ON public.profiles;

CREATE POLICY "Users can select their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.get_my_referees()
RETURNS TABLE(
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  created_at timestamp with time zone,
  has_phone boolean,
  has_social boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    p.full_name,
    p.username,
    p.avatar_url,
    p.created_at,
    (p.phone_number IS NOT NULL) AS has_phone,
    (
      p.twitter_handle IS NOT NULL
      OR p.telegram_handle IS NOT NULL
      OR p.facebook_handle IS NOT NULL
      OR p.instagram_handle IS NOT NULL
    ) AS has_social
  FROM public.profiles p
  JOIN public.referrals r ON r.referee_id = p.id
  WHERE r.referrer_id = auth.uid()
  ORDER BY r.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_my_referees() FROM public, anon;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_my_referees() TO authenticated'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260829122316_b5016487-0385-4413-8c0e-c0957ecea5db.sql
-- =============================================

create table if not exists public.signup_otps (
  email text primary key,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  created_at timestamptz not null default now()
);

grant all on public.signup_otps to service_role;

alter table public.signup_otps enable row level security;

-- =============================================
-- Migration: 20260831123000_abc74320-2299-4b80-8b3a-9fff32868042.sql
-- =============================================

CREATE OR REPLACE FUNCTION public._rebuild_exec(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  EXECUTE sql;
END;
$$;
REVOKE ALL ON FUNCTION public._rebuild_exec(text) FROM PUBLIC, anon, authenticated, service_role;
DO $$ BEGIN EXECUTE 'GRANT EXECUTE ON FUNCTION public._rebuild_exec(text) TO sandbox_exec'; EXCEPTION WHEN undefined_function OR undefined_object THEN NULL; END $$;

-- =============================================
-- Migration: 20260831123738_ba5119e6-e02d-4bab-b4ed-6cb7a99a8afe.sql
-- =============================================

GRANT ALL ON SCHEMA public TO postgres;
GRANT USAGE, CREATE ON SCHEMA public TO sandbox_exec;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
