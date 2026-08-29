-- Fix the security definer view by making it a simple view (RLS on profiles will apply)
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard AS
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

-- Revoke public execution of handle_new_user to satisfy linter
-- The postgres and service_role grants are enough for the trigger to work
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated, anon;
