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
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role;

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
GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text) TO authenticated, service_role;

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
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role;