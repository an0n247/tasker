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
