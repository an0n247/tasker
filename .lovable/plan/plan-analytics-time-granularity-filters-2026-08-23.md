# Plan - Analytics Time Granularity Filters

Add the ability to toggle between daily, weekly, and monthly views in the Admin Analytics dashboard to better understand long-term trends.

## User Review Required

> [!IMPORTANT]
> The "weekly" and "monthly" views will group data by the start of the week (Monday) and start of the month respectively.

## Proposed Changes

### Database Layer

- Update `get_daily_task_completions` RPC to accept a `granularity` parameter ('day', 'week', 'month').
- Update the SQL logic to use `date_trunc(granularity, created_at)` for grouping.

### Frontend Layer

#### `src/components/admin/AnalyticsView.tsx`
- Add a new `granularity` state (defaulting to 'day').
- Implement a `Tabs` or `ToggleGroup` in the filter bar for "Daily", "Weekly", "Monthly".
- Update the `useQuery` for `economyData` to pass the `granularity` to the RPC.
- Adjust chart labels based on the selected granularity (e.g., "Week of..." or "Month...").

## Technical Details

### SQL Update

```sql
CREATE OR REPLACE FUNCTION public.get_task_completions_stats(
  start_date timestamptz, 
  end_date timestamptz, 
  granularity text DEFAULT 'day',
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (period date, count bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    date_trunc(granularity, created_at)::date as period,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
    AND (filter_task_id IS NULL OR task_id = filter_task_id)
  GROUP BY 1
  ORDER BY 1 ASC;
$$;
```

### Component Logic
- The `granularity` parameter must be one of `['day', 'week', 'month']`.
- Date formatting in Recharts `XAxis` will use conditional `tickFormatter`:
  - Day: `MMM d`
  - Week: `'Week ' + format(date, 'w')` or `MMM d` (start of week)
  - Month: `MMM yyyy`
