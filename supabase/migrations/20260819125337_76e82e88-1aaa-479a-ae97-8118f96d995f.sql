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
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;
