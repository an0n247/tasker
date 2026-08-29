ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS welcome_banner_dismissed BOOLEAN DEFAULT FALSE;
