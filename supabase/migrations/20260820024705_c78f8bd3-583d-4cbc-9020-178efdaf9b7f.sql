
-- Add updated_at column to redemptions table
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop the trigger if it exists and recreate it
DROP TRIGGER IF EXISTS update_redemptions_updated_at ON public.redemptions;
CREATE TRIGGER update_redemptions_updated_at
    BEFORE UPDATE ON public.redemptions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
