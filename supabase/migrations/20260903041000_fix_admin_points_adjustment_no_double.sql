-- ==============================================================================
-- 1. Fix handle_admin_points_adjustment to prevent doubling of points
-- Because points_transactions has an AFTER INSERT trigger (update_user_points_balance)
-- that increments profiles.points_balance automatically, handle_admin_points_adjustment
-- must NOT manually update profiles.points_balance directly.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(
  p_target_user_id uuid,
  p_amount integer,
  p_action_type text,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
  v_delta integer;
  v_transaction_id uuid;
  v_reason text := COALESCE(NULLIF(btrim(p_reason), ''), 'Admin adjustment');
BEGIN
  IF v_admin_id IS NULL OR (
    NOT public.has_role(v_admin_id, 'admin') 
    AND LOWER(COALESCE(auth.jwt() ->> 'email', '')) NOT IN ('olalekanhq@yahoo.com')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Only administrators can adjust user points';
  END IF;

  IF p_action_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Invalid adjustment type: must be credit or debit';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Adjustment amount must be greater than zero';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
    RAISE EXCEPTION 'Target user not found';
  END IF;

  v_delta := CASE WHEN p_action_type = 'debit' THEN -abs(p_amount) ELSE abs(p_amount) END;

  -- NOTE: We ONLY insert into points_transactions.
  -- The on_points_transaction_change trigger handles updating profiles.points_balance atomically.
  INSERT INTO public.points_transactions (user_id, amount, type, description, status)
  VALUES (
    p_target_user_id, 
    v_delta, 
    CASE WHEN v_delta < 0 THEN 'admin_debit' ELSE 'admin_credit' END, 
    'Admin ' || p_action_type || ': ' || v_reason,
    'completed'
  )
  RETURNING id INTO v_transaction_id;

  -- Log in points audit logs
  INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
  VALUES (p_target_user_id, v_delta, 'Admin ' || p_action_type || ': ' || v_reason, 'manual_admin_action');

  -- Log in admin audit logs
  INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
  VALUES (
    v_admin_id,
    'points_adjustment',
    'profiles',
    p_target_user_id::text,
    jsonb_build_object(
      'amount', v_delta,
      'reason', v_reason,
      'action_type', p_action_type,
      'transaction_id', v_transaction_id
    )
  );

  RETURN jsonb_build_object('success', true, 'transaction_id', v_transaction_id, 'amount', v_delta);
END;
$$;

REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated, service_role;


-- ==============================================================================
-- 2. Clear out all existing messages from public.messages
-- ==============================================================================
DELETE FROM public.messages;


-- ==============================================================================
-- 3. Resynchronize and fix any doubled balances from previous adjustments
-- Calculates accurate points_balance from points_transactions
-- ==============================================================================
UPDATE public.profiles p
SET points_balance = GREATEST(0, COALESCE((
    SELECT SUM(pt.amount) 
    FROM public.points_transactions pt 
    WHERE pt.user_id = p.id 
      AND (pt.status IS NULL OR pt.status = 'completed')
), 0));
