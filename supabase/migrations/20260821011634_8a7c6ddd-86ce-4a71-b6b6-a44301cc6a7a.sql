-- Restore access to referral validation for anonymous users (needed during signup)
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon;

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
