-- Attempt to explicitly drop both potential signatures to clear any ambiguity
DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text);
DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text, text);

-- Re-create the function with a single clear signature
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(
  _redemption_id uuid,
  _new_status text,
  _rejection_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_points integer;
  v_old_status text;
  v_result jsonb;
  v_refunded boolean DEFAULT false;
  v_re_deducted boolean DEFAULT false;
BEGIN
  -- Get current status and details
  SELECT user_id, status, (SELECT rewards.cost_points FROM rewards WHERE rewards.id = redemptions.reward_id)
  INTO v_user_id, v_old_status, v_points
  FROM redemptions
  WHERE id = _redemption_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
  END IF;

  -- Handle point adjustments
  -- 1. Refund points if moving TO rejected from something else
  IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
    UPDATE profiles 
    SET points_balance = points_balance + v_points 
    WHERE id = v_user_id;
    
    INSERT INTO points_transactions (user_id, amount, type, description)
    VALUES (v_user_id, v_points, 'referral_bonus', 'Refund: Reward redemption rejected');
    
    v_refunded := true;
  END IF;

  -- 2. Deduct points if moving FROM rejected to something else
  IF v_old_status = 'rejected' AND _new_status != 'rejected' THEN
    -- Check if user has enough points
    IF (SELECT points_balance FROM profiles WHERE id = v_user_id) < v_points THEN
      RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-deduct for this reward');
    END IF;

    UPDATE profiles 
    SET points_balance = points_balance - v_points 
    WHERE id = v_user_id;
    
    INSERT INTO points_transactions (user_id, amount, type, description)
    VALUES (v_user_id, -v_points, 'redemption', 'Re-deduction: Reward redemption re-activated');
    
    v_re_deducted := true;
  END IF;

  -- Update the redemption record
  UPDATE redemptions
  SET 
    status = _new_status,
    rejection_reason = CASE 
      WHEN _new_status = 'rejected' THEN _rejection_reason 
      ELSE NULL 
    END,
    updated_at = now()
  WHERE id = _redemption_id;

  RETURN jsonb_build_object(
    'success', true, 
    'message', 'Status updated successfully',
    'refunded', v_refunded,
    're_deducted', v_re_deducted
  );
END;
$$;

-- Explicitly grant permissions
REVOKE ALL ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role;