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