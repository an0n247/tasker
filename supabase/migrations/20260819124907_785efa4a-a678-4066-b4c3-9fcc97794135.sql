CREATE OR REPLACE VIEW public.leaderboard AS
SELECT 
    p.id,
    p.full_name,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

-- Add referral rewards progress tracking if not exists
-- We can track how many referrals are "completed" (e.g., have earned points)
-- For now, let's just make sure we have a way to count them easily.
