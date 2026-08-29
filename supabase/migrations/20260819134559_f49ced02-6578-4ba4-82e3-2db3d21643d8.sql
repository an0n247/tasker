
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
