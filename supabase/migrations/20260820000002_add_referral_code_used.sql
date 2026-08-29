ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS referral_code_used TEXT;
COMMENT ON COLUMN public.profiles.referral_code_used IS 'The referral code (username) that was used by this user to sign up.';
