
-- Grant SELECT on public tables to authenticated and anon where appropriate
GRANT SELECT ON public.tasks TO authenticated, anon;
GRANT SELECT ON public.rewards TO authenticated, anon;
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT ON public.user_roles TO authenticated;
GRANT SELECT ON public.points_transactions TO authenticated;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT SELECT ON public.user_streaks TO authenticated;
GRANT SELECT ON public.task_submissions TO authenticated;

-- Grant ALL on public tables to service_role
GRANT ALL ON public.tasks TO service_role;
GRANT ALL ON public.rewards TO service_role;
GRANT ALL ON public.profiles TO service_role;
GRANT ALL ON public.user_roles TO service_role;
GRANT ALL ON public.points_transactions TO service_role;
GRANT ALL ON public.rewards TO service_role;
GRANT ALL ON public.points_transactions TO service_role;
GRANT ALL ON public.redemptions TO service_role;
GRANT ALL ON public.notifications TO service_role;
GRANT ALL ON public.user_streaks TO service_role;
GRANT ALL ON public.task_submissions TO service_role;
