-- Add referral clicks tracking to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_clicks INTEGER DEFAULT 0;

-- Function to increment clicks
CREATE OR REPLACE FUNCTION public.increment_referral_clicks(target_referral_code TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles
    SET referral_clicks = referral_clicks + 1
    WHERE referral_code = target_referral_code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO anon, authenticated;
