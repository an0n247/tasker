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