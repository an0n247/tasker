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