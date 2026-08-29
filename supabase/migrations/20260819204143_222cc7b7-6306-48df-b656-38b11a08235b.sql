
-- Create admin audit logs table
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id),
    target_table TEXT NOT NULL,
    target_id UUID NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT SELECT ON public.admin_audit_logs TO authenticated;
GRANT ALL ON public.admin_audit_logs TO service_role;

-- RLS Policy: Only admins can view audit logs
CREATE POLICY "Admins can view audit logs"
ON public.admin_audit_logs
FOR SELECT
TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Trigger function to log admin actions
CREATE OR REPLACE FUNCTION public.handle_admin_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    current_admin_id UUID;
BEGIN
    current_admin_id := auth.uid();
    
    -- We only log if it's an authenticated user (admin) making the change
    -- If current_admin_id is null, it might be a system action or service role
    -- but we usually want to track who did what in the UI.
    
    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, new_data)
        VALUES (current_admin_id, TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data, new_data)
        VALUES (current_admin_id, TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        INSERT INTO public.admin_audit_logs (admin_id, target_table, target_id, action_type, old_data)
        VALUES (current_admin_id, TG_TABLE_NAME, OLD.id, TG_OP, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for tasks
CREATE TRIGGER audit_tasks_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION public.handle_admin_audit_log();

-- Create triggers for rewards
CREATE TRIGGER audit_rewards_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.rewards
FOR EACH ROW EXECUTE FUNCTION public.handle_admin_audit_log();
