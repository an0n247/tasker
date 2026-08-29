-- 1. Add 'tasker' to app_role enum
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'tasker';

-- 2. Create role_permissions table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role public.app_role NOT NULL,
    tab_name TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    UNIQUE(role, tab_name)
);

-- 3. Grant access
GRANT SELECT, INSERT, UPDATE, DELETE ON public.role_permissions TO authenticated;
GRANT ALL ON public.role_permissions TO service_role;

-- 4. Enable RLS
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- 5. Create Policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Admins can manage all role permissions' AND tablename = 'role_permissions'
    ) THEN
        CREATE POLICY "Admins can manage all role permissions"
        ON public.role_permissions
        FOR ALL
        TO authenticated
        USING (public.has_role(auth.uid(), 'admin'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'All authenticated users can read permissions' AND tablename = 'role_permissions'
    ) THEN
        CREATE POLICY "All authenticated users can read permissions"
        ON public.role_permissions
        FOR SELECT
        TO authenticated
        USING (true);
    END IF;
END
$$;
