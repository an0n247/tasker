# Plan: Analytics Drill-down Filters

Implement task-specific drill-down filters in the Analytics tab to allow administrators to analyze completions and repeatable claim rates for individual tasks.

## User Review Required

> [!IMPORTANT]
> The drill-down will allow selecting a specific task to filter both the "Daily Completions" and "Repeatable Task Stats" charts. Does this meet your requirements, or did you want separate task selectors for each chart?

## Proposed Changes

### Database Functions
- Update `get_daily_task_completions` RPC to accept an optional `filter_task_id` parameter.
- Update `get_repeatable_task_stats` RPC to accept an optional `filter_task_id` parameter.

### Analytics Component (`src/components/admin/AnalyticsView.tsx`)
- Add a task selector (Combobox or Select) to the filter bar.
- Fetch all active tasks to populate the selector.
- Update `useQuery` hooks to include `selectedTaskId` in the dependency array and pass it to the RPCs.
- Add a "Clear Filter" option to return to global platform views.

## Technical Details

### SQL Updates
```sql
CREATE OR REPLACE FUNCTION public.get_daily_task_completions(
  start_date timestamptz, 
  end_date timestamptz, 
  filter_task_id uuid DEFAULT NULL
)
RETURNS TABLE (completion_date date, count bigint)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT 
    date_trunc('day', created_at)::date as completion_date,
    count(*) as count
  FROM public.task_submissions
  WHERE status = 'approved'
    AND created_at >= start_date
    AND created_at <= end_date
    AND (filter_task_id IS NULL OR task_id = filter_task_id)
  GROUP BY 1 ORDER BY 1 ASC;
$$;
```

### Frontend Implementation
- Use `shadcn/ui` Select component for task selection.
- Update state management to handle the `selectedTaskId`.
- Ensure charts display clear "No data found for this task" messages when applicable.
