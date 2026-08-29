-- Update task completions RPC to include granularity
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, 
  end_date timestamptz, 
  granularity text DEFAULT 'day',
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate granularity to prevent SQL injection or invalid truncations
  IF granularity NOT IN ('day', 'week', 'month') THEN
    granularity := 'day';
  END IF;

  RETURN QUERY
  SELECT 
    date_trunc(granularity, created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
    AND (filter_task_id IS NULL OR task_id = filter_task_id)
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$$;

-- Ensure grants are correct for the new signature
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO service_role;
