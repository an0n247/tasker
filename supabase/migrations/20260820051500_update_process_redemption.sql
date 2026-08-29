-- Update process_redemption_status_change to handle review_required state
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(_redemption_id uuid, _new_status text, _rejection_reason text DEFAULT '')
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_redemption record;
    v_reward record;
    v_now timestamp with time zone := now();
    v_refunded boolean := false;
    v_re_deducted boolean := false;
BEGIN
    -- 1. Check if admin
    IF NOT public.has_role(auth.uid(), 'admin') THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized. Admin only.');
    END IF;

    -- 2. Get redemption record
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Redemption not found.');
    END IF;

    -- 3. Get reward details for points info
    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    
    -- 4. Check if we need to refund (transition from something non-rejected to rejected)
    IF _new_status = 'rejected' AND v_redemption.status <> 'rejected' THEN
        UPDATE public.profiles
        SET points_balance = points_balance + v_reward.cost_points
        WHERE id = v_redemption.user_id;
        
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (v_redemption.user_id, v_reward.cost_points, 'earn', 'Refund for rejected reward: ' || v_reward.title, v_now);
        
        v_refunded := true;
    END IF;

    -- 5. Check if we need to re-deduct (transition from rejected to something else)
    IF v_redemption.status = 'rejected' AND _new_status <> 'rejected' THEN
        -- Check if user has enough balance
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_redemption.user_id AND points_balance >= v_reward.cost_points) THEN
            RETURN json_build_object('success', false, 'message', 'User no longer has enough points for this reward.');
        END IF;

        UPDATE public.profiles
        SET points_balance = points_balance - v_reward.cost_points
        WHERE id = v_redemption.user_id;
        
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (v_redemption.user_id, -v_reward.cost_points, 'redeem', 'Points re-deducted for reward: ' || v_reward.title, v_now);
        
        v_re_deducted := true;
    END IF;

    -- 6. Update the record
    UPDATE public.redemptions
    SET 
        status = _new_status,
        rejection_reason = CASE WHEN _new_status = 'rejected' THEN _rejection_reason ELSE NULL END,
        updated_at = v_now,
        -- Auto-clear flags if approved by admin
        is_flagged = CASE WHEN _new_status = 'approved' THEN false ELSE is_flagged END
    WHERE id = _redemption_id;

    -- 7. Audit log
    INSERT INTO public.admin_audit_logs (action_type, target_table, target_id, new_data, old_data)
    VALUES ('status_change', 'redemptions', _redemption_id, json_build_object('status', _new_status, 'reason', _rejection_reason), json_build_object('status', v_redemption.status));

    RETURN json_build_object(
        'success', true, 
        'refunded', v_refunded, 
        're_deducted', v_re_deducted, 
        'message', 'Status updated successfully.'
    );
END;
$$;
