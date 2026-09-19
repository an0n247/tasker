-- Ensure authenticated users can select their own redemptions to track redemption history
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'redemptions' 
        AND policyname = 'Users can read their own redemptions'
    ) THEN
        CREATE POLICY "Users can read their own redemptions" ON public.redemptions
            FOR SELECT TO authenticated
            USING (auth.uid() = user_id);
    END IF;
END $$;

GRANT SELECT ON public.redemptions TO authenticated;

-- Create a helper function get_my_redemptions() that securely returns the current user's redemption history
CREATE OR REPLACE FUNCTION public.get_my_redemptions()
RETURNS TABLE (
  id uuid,
  user_id uuid,
  reward_id uuid,
  status text,
  wallet_address text,
  delivery_email text,
  payout_network text,
  rejection_reason text,
  created_at timestamptz,
  updated_at timestamptz,
  reward_title text,
  reward_cost_points integer,
  reward_category text,
  reward_image_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.user_id,
    r.reward_id,
    r.status,
    r.wallet_address,
    r.delivery_email,
    r.payout_network,
    r.rejection_reason,
    r.created_at,
    r.updated_at,
    rw.title AS reward_title,
    rw.cost_points AS reward_cost_points,
    rw.category AS reward_category,
    rw.image_url AS reward_image_url
  FROM public.redemptions r
  LEFT JOIN public.rewards rw ON rw.id = r.reward_id
  WHERE r.user_id = auth.uid()
  ORDER BY r.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_redemptions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_redemptions() TO authenticated;

-- Reload postgrest schema cache
NOTIFY pgrst, 'reload schema';
