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
GRANT EXECUTE ON FUNCTION public.get_my_referees() TO authenticated;