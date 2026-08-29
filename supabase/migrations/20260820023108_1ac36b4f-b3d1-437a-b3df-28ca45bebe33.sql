-- Function to handle redemption status changes with point refunds/deductions
CREATE OR REPLACE FUNCTION public.process_redemption_status_change(
    _redemption_id UUID,
    _new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_redemption RECORD;
    v_reward RECORD;
    v_profile RECORD;
    v_old_status TEXT;
    v_cost INTEGER;
    v_admin_id UUID;
BEGIN
    -- Get current user ID (must be admin)
    v_admin_id := auth.uid();
    
    IF NOT public.has_role(v_admin_id, 'admin') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin role required');
    END IF;

    -- Get redemption details
    SELECT * INTO v_redemption FROM public.redemptions WHERE id = _redemption_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Redemption not found');
    END IF;

    v_old_status := v_redemption.status;
    
    -- If status hasn't changed, just return success
    IF v_old_status = _new_status THEN
        RETURN jsonb_build_object('success', true, 'message', 'Status unchanged');
    END IF;

    -- Get reward details for cost
    SELECT * INTO v_reward FROM public.rewards WHERE id = v_redemption.reward_id;
    v_cost := v_reward.cost_points;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_redemption.user_id FOR UPDATE;

    -- LOGIC FOR REFUNDS (Moving TO Rejected from any other status)
    IF _new_status = 'rejected' AND v_old_status != 'rejected' THEN
        -- Refund points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, v_cost, 'earn', 'Refund: Rejected "' || v_reward.title || '" redemption', _redemption_id);
        
        -- points_balance is updated by trigger on points_transactions
    END IF;

    -- LOGIC FOR RE-DEDUCTION (Moving FROM Rejected to Approved or Pending)
    IF v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending') THEN
        -- Check if user has enough points to re-deduct
        IF v_profile.points_balance < v_cost THEN
            RETURN jsonb_build_object('success', false, 'message', 'User has insufficient points to re-process this redemption');
        END IF;

        -- Re-deduct points
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_redemption.user_id, -v_cost, 'spend', 'Re-processing "' || v_reward.title || '" redemption', _redemption_id);
    END IF;

    -- Update redemption status
    UPDATE public.redemptions
    SET status = _new_status
    WHERE id = _redemption_id;

    -- Create audit log
    INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
    VALUES (
        v_admin_id,
        'redemptions',
        _redemption_id,
        'update_status',
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', _new_status)
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Redemption status updated to ' || _new_status,
        'refunded', (_new_status = 'rejected' AND v_old_status != 'rejected'),
        're_deducted', (v_old_status = 'rejected' AND (_new_status = 'approved' OR _new_status = 'pending'))
    );
END;
$$;

-- Grant execute to authenticated users (role check inside function handles security)
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO service_role;
