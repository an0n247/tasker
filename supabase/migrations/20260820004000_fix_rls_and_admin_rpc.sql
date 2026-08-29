-- 1. Create a dedicated RPC for admins to adjust points
CREATE OR REPLACE FUNCTION public.admin_adjust_points(
    _user_id uuid, 
    _amount integer, 
    _type text, 
    _description text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Security check: only admins can call this
    IF NOT public.has_role(auth.uid(), 'admin') THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Insert the transaction
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, _amount, _type, _description);

    RETURN json_build_object('success', true, 'message', 'Points adjusted successfully');
END;
$$;

-- 2. Revoke and Grant for the new RPC
REVOKE ALL ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) TO authenticated;

-- 3. Ensure proper GRANTs on redemptions and points_transactions
-- These are often missing or dropped in previous migrations
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;

-- 4. Update the redemptions policy to allow the system (SECURITY DEFINER) to insert
-- RLS policies don't apply to SECURITY DEFINER functions owned by a superuser/admin role
-- but sometimes explicit policies help if the function is not acting as owner.
-- The existing policies should be fine, but let's ensure service_role can do everything.
