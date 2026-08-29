
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
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.lookup_login_email(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.increment_referral_clicks(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_daily_reward(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.assign_role(uuid, app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, app_role) TO authenticated;

REVOKE ALL ON FUNCTION public.remove_role(uuid, app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, app_role) TO authenticated;

REVOKE ALL ON FUNCTION public.redeem_reward(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
