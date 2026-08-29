
-- Revoke execute from public to satisfy linter for SECURITY DEFINER functions
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres;

REVOKE ALL ON FUNCTION public.get_user_email_by_username(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_email_by_username(TEXT) TO authenticated, anon, service_role;

-- Re-create the view with security_invoker = true to satisfy linter (lint 0010)
DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = true) AS
SELECT 
    p.id,
    p.full_name,
    p.username,
    p.avatar_url,
    p.points_balance,
    RANK() OVER (ORDER BY p.points_balance DESC) as rank
FROM public.profiles p
ORDER BY p.points_balance DESC
LIMIT 100;

GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;
