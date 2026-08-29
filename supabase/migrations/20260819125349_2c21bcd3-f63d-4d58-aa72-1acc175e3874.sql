-- Explicitly ensure the view is not security definer and the function is locked down
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = on) AS
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

-- Re-verify function permissions
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated, anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;
