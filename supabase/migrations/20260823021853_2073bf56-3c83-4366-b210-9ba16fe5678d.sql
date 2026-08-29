
-- Function to get daily task completions for analytics
CREATE OR REPLACE VIEW public.daily_task_completions AS
SELECT 
  date_trunc('day', created_at)::date as completion_date,
  count(*) as count
FROM public.task_submissions
WHERE status = 'approved'
GROUP BY 1
ORDER BY 1 DESC;

-- View for repeatable task claim rates (last 30 days)
CREATE OR REPLACE VIEW public.repeatable_task_stats AS
SELECT 
  t.id,
  t.title,
  count(ts.id) as total_claims,
  count(distinct ts.user_id) as unique_users,
  round(count(ts.id)::numeric / nullif(count(distinct ts.user_id), 0), 2) as claims_per_user
FROM public.tasks t
JOIN public.task_submissions ts ON t.id = ts.task_id
WHERE t.is_repeatable = true 
  AND ts.status = 'approved'
  AND ts.created_at > now() - interval '30 days'
GROUP BY 1, 2;

GRANT SELECT ON public.daily_task_completions TO authenticated;
GRANT SELECT ON public.repeatable_task_stats TO authenticated;
GRANT SELECT ON public.daily_task_completions TO service_role;
GRANT SELECT ON public.repeatable_task_stats TO service_role;
