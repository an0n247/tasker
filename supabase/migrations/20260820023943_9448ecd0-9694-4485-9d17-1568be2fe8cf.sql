ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;
