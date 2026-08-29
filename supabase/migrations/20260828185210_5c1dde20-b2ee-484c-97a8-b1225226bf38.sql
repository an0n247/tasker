
DROP FUNCTION IF EXISTS public.get_daily_task_completions(timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.get_daily_task_completions(timestamptz, timestamptz, uuid);
DROP FUNCTION IF EXISTS public.get_repeatable_task_stats(timestamptz, timestamptz);

CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, end_date timestamptz,
  granularity text DEFAULT 'day', filter_task_id uuid DEFAULT NULL)
RETURNS TABLE(completion_date date, count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF granularity NOT IN ('day', 'week', 'month') THEN granularity := 'day'; END IF;
  RETURN QUERY
  SELECT date_trunc(granularity, ts.created_at)::date, count(*)
  FROM public.task_submissions ts
  WHERE ts.status IN ('verified', 'approved')
    AND ts.created_at >= start_date AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR ts.task_id = filter_task_id)
  GROUP BY 1 ORDER BY 1;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_repeatable_task_stats(
  start_date timestamptz, end_date timestamptz, filter_task_id uuid DEFAULT NULL)
RETURNS TABLE(id uuid, title text, total_claims bigint, unique_users bigint, claims_per_user numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT t.id, t.title, count(ts.id), count(DISTINCT ts.user_id),
    round(count(ts.id)::numeric / nullif(count(DISTINCT ts.user_id), 0), 2)
  FROM public.tasks t
  JOIN public.task_submissions ts ON t.id = ts.task_id
  WHERE ts.status IN ('verified', 'approved')
    AND ts.created_at >= start_date AND ts.created_at <= end_date
    AND (filter_task_id IS NULL OR t.id = filter_task_id)
  GROUP BY t.id, t.title
  ORDER BY 3 DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_funnel_stats(start_date timestamptz, end_date timestamptz)
RETURNS TABLE(referrals bigint, signups bigint, bonuses bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.referrals r
       WHERE r.created_at >= start_date AND r.created_at <= end_date),
    (SELECT count(*) FROM public.profiles p
       WHERE p.created_at >= start_date AND p.created_at <= end_date),
    (SELECT count(*) FROM public.profiles p
       WHERE p.has_claimed_welcome_bonus = true
         AND p.created_at >= start_date AND p.created_at <= end_date);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_funnel_stats(timestamptz, timestamptz) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.get_funnel_stats(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO authenticated;
