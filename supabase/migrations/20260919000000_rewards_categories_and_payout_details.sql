-- Add payout destination columns to redemptions table
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS wallet_address TEXT;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS delivery_email TEXT;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS payout_network TEXT DEFAULT 'USDT (TRC20)';

-- Ensure category column on rewards defaults appropriately and normalize existing data
ALTER TABLE public.rewards ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Gift Card';

-- Update existing rewards category names to normalized values
UPDATE public.rewards
SET category = 'Crypto'
WHERE LOWER(category) LIKE '%crypto%' OR LOWER(title) LIKE '%crypto%' OR LOWER(title) LIKE '%usdt%';

UPDATE public.rewards
SET category = 'Gift Card'
WHERE category IS NULL OR (LOWER(category) != 'crypto' AND LOWER(category) NOT LIKE '%crypto%');

-- Drop existing functions to allow new signature
DROP FUNCTION IF EXISTS public.redeem_reward(uuid);
DROP FUNCTION IF EXISTS public.redeem_reward(uuid, text, text);

-- Recreate redeem_reward function with wallet_address and delivery_email parameters
CREATE OR REPLACE FUNCTION public.redeem_reward(
  _reward_id uuid,
  _wallet_address text DEFAULT NULL,
  _delivery_email text DEFAULT NULL
)
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
  v_category text;
  v_balance integer;
  v_user_email text;
  v_redemption_id uuid;
  v_clean_wallet text;
  v_clean_email text;
  v_network text := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  SELECT cost_points, stock_count, is_active, title, category
    INTO v_cost, v_stock, v_active, v_title, v_category
  FROM public.rewards WHERE id = _reward_id FOR UPDATE;

  IF NOT FOUND OR NOT v_active THEN
    RETURN jsonb_build_object('success', false, 'message', 'Reward not available');
  END IF;

  IF v_stock IS NOT NULL AND v_stock <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Reward is out of stock');
  END IF;

  SELECT points_balance, email INTO v_balance, v_user_email
  FROM public.profiles WHERE id = v_user_id FOR UPDATE;

  IF v_balance IS NULL OR v_balance < v_cost THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient points');
  END IF;

  -- Validate payout details based on category
  IF LOWER(COALESCE(v_category, '')) = 'crypto' THEN
    v_clean_wallet := TRIM(COALESCE(_wallet_address, ''));
    IF v_clean_wallet = '' THEN
      RETURN jsonb_build_object('success', false, 'message', 'A valid USDT (TRC20) wallet address is required.');
    END IF;

    -- Basic format check for Tron TRC20 wallet address: starts with T, usually 34 chars
    IF NOT (v_clean_wallet ~ '^T[1-9A-HJ-NP-za-km-z]{33}$') AND NOT (v_clean_wallet ~ '^T[0-9a-zA-Z]{25,50}$') THEN
      RETURN jsonb_build_object('success', false, 'message', 'Invalid USDT TRC20 wallet address. TRC20 addresses start with T.');
    END IF;

    v_network := 'USDT (TRC20)';
  ELSE
    -- Gift card reward: default to user's registered email
    v_clean_email := COALESCE(NULLIF(TRIM(_delivery_email), ''), v_user_email);
    IF v_clean_email IS NULL OR v_clean_email = '' THEN
      RETURN jsonb_build_object('success', false, 'message', 'A valid registered email is required for gift card delivery.');
    END IF;
  END IF;

  -- Deduct user points
  UPDATE public.profiles SET points_balance = points_balance - v_cost WHERE id = v_user_id;

  -- Decrease stock if tracked
  IF v_stock IS NOT NULL THEN
    UPDATE public.rewards SET stock_count = stock_count - 1 WHERE id = _reward_id;
  END IF;

  -- Record redemption with payout details
  INSERT INTO public.redemptions (
    user_id,
    reward_id,
    status,
    wallet_address,
    delivery_email,
    payout_network
  )
  VALUES (
    v_user_id,
    _reward_id,
    'pending',
    v_clean_wallet,
    v_clean_email,
    v_network
  )
  RETURNING id INTO v_redemption_id;

  -- Ledger transaction record
  INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
  VALUES (v_user_id, -v_cost, 'redemption', 'Redeemed reward: ' || v_title, v_redemption_id);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Redemption submitted',
    'redemption_id', v_redemption_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_reward(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid, text, text) TO authenticated, service_role;
