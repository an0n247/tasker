-- Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT SELECT ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policies
-- First drop if exists to avoid errors on retry
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow read access for authenticated users' AND tablename = 'app_settings') THEN
        DROP POLICY "Allow read access for authenticated users" ON public.app_settings;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow admin to manage settings' AND tablename = 'app_settings') THEN
        DROP POLICY "Allow admin to manage settings" ON public.app_settings;
    END IF;
END $$;

CREATE POLICY "Allow read access for authenticated users" 
ON public.app_settings FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Allow admin to manage settings" 
ON public.app_settings FOR ALL 
TO authenticated 
USING (public.has_role(auth.uid(), 'admin'));

-- Initial Settings
INSERT INTO public.app_settings (key, value, description)
VALUES 
('welcome_bonus_enabled', 'true'::jsonb, 'Enable or disable the welcome bonus for referred users'),
('welcome_bonus_amount_referee', '50'::jsonb, 'Amount of points given to the new user (referee)'),
('welcome_bonus_amount_referrer', '75'::jsonb, 'Amount of points given to the user who invited them (referrer)'),
('welcome_bonus_required_socials', '["twitter", "telegram"]'::jsonb, 'List of social handles required to claim the bonus')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description;
