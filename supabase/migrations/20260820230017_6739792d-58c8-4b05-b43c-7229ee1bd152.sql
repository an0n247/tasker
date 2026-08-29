-- Speed up stats and list sorting
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_points_transactions_created_at ON public.points_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_redemptions_created_at ON public.redemptions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_created_at ON public.referrals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);