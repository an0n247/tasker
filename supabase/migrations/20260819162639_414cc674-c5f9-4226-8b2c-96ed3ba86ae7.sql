ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Update RLS if necessary (it should already be covered by existing policies)
-- But let's re-grant to be safe
GRANT SELECT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
