-- The view currently uses SECURITY DEFINER by default which enforces view creator permissions.
-- We switch it to SECURITY INVOKER by recreating it as a simple view (which is invoker by default in Postgres 15+ or when not specified)
-- or explicitly setting it if the environment supports it.

DROP VIEW IF EXISTS public.user_daily_task_counts;

CREATE OR REPLACE VIEW public.user_daily_task_counts 
WITH (security_invoker = true)
AS
SELECT 
    user_id, 
    COUNT(*) as daily_count
FROM 
    public.task_submissions
WHERE 
    status = 'verified' AND
    (created_at AT TIME ZONE 'GMT')::date = (CURRENT_DATE AT TIME ZONE 'GMT')
GROUP BY 
    user_id;

GRANT SELECT ON public.user_daily_task_counts TO authenticated;
GRANT SELECT ON public.user_daily_task_counts TO service_role;
