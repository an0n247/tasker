CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
    p_admin_id UUID,
    p_target_user_id UUID,
    p_amount INTEGER,
    p_action_type TEXT,
    p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_role app_role;
    v_transaction_id UUID;
    v_final_amount INTEGER;
BEGIN
    -- 1. Security check: verify caller is admin
    SELECT role INTO v_admin_role FROM public.user_roles WHERE user_id = p_admin_id AND role = 'admin';
    
    IF v_admin_role IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
    END IF;

    -- 2. Determine final amount (credit is positive, debit is negative)
    IF p_action_type = 'credit' THEN
        v_final_amount := ABS(p_amount);
    ELSE
        v_final_amount := -ABS(p_amount);
    END IF;

    -- 3. Record transaction
    INSERT INTO public.points_transactions (
        user_id,
        amount,
        type,
        description,
        status
    ) VALUES (
        p_target_user_id,
        v_final_amount,
        'adjustment',
        'Admin adjustment: ' || p_reason,
        'completed'
    ) RETURNING id INTO v_transaction_id;

    -- 4. Update profile balance
    UPDATE public.profiles
    SET points_balance = points_balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    -- 5. Record in points_audit_logs
    INSERT INTO public.points_audit_logs (
        user_id,
        amount,
        reason,
        trigger_name
    ) VALUES (
        p_target_user_id,
        v_final_amount,
        'Admin Adjustment: ' || p_reason,
        'manual_admin_action'
    );

    -- 6. Log in admin_audit_logs
    INSERT INTO public.admin_audit_logs (
        admin_id,
        action_type,
        target_table,
        target_id,
        new_data
    ) VALUES (
        p_admin_id,
        'points_adjustment',
        'profiles',
        p_target_user_id,
        jsonb_build_object(
            'amount', v_final_amount,
            'reason', p_reason,
            'transaction_id', v_transaction_id
        )
    );

    -- 7. Send notification to user
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        transaction_id
    ) VALUES (
        p_target_user_id,
        'Points Adjusted',
        'Your points balance has been adjusted by ' || v_final_amount || ' points. Reason: ' || p_reason,
        'points',
        v_transaction_id
    );

END;
$$;
