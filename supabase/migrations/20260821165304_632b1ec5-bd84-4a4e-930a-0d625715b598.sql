
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'points_audit_logs') THEN
        CREATE TABLE public.points_audit_logs (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id uuid REFERENCES auth.users(id) NOT NULL,
            amount integer NOT NULL,
            reason text NOT NULL,
            trigger_name text NOT NULL,
            created_at timestamp with time zone DEFAULT now()
        );

        GRANT SELECT ON public.points_audit_logs TO authenticated;
        GRANT ALL ON public.points_audit_logs TO service_role;
        ALTER TABLE public.points_audit_logs ENABLE ROW LEVEL SECURITY;

        CREATE POLICY "Admins can see all points audit logs"
        ON public.points_audit_logs FOR SELECT
        TO authenticated
        USING (public.has_role(auth.uid(), 'admin'));
    END IF;
END $$;

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
BEGIN
    -- 1. Check if caller is admin
    IF NOT EXISTS (SELECT 1 FROM user_roles WHERE user_id = p_admin_id AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can adjust points';
    END IF;

    -- 2. Apply transaction
    PERFORM handle_points_transaction(
        p_target_user_id,
        CASE WHEN p_action_type = 'credit' THEN ABS(p_amount) ELSE -ABS(p_amount) END,
        'Admin adjustment: ' || p_reason,
        'adjustment'
    );

    -- 3. Log to points_audit_logs
    INSERT INTO points_audit_logs (user_id, amount, reason, trigger_name)
    VALUES (
        p_target_user_id,
        CASE WHEN p_action_type = 'credit' THEN ABS(p_amount) ELSE -ABS(p_amount) END,
        'ADMIN_' || UPPER(p_action_type) || ': ' || p_reason,
        'admin_manual_action'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment TO authenticated;
