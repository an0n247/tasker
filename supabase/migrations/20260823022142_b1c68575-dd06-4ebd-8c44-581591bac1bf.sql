
-- RPC for daily task completions with date filtering
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(start_date timestamptz, end_date timestamptz)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    date_trunc('day', created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
  GROUP BY 1
  ORDER BY 1 ASC;
$$;

-- RPC for repeatable task stats with date filtering
CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(start_date timestamptz, end_date timestamptz)
RETURNS TABLE (id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
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
    AND ts.created_at >= start_date
    AND ts.created_at <= end_date
  GROUP BY 1, 2;
$$;

GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO service_role;
