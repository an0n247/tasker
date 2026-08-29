# Plan - Task Limits, Daily Reset, and Repeatable Tasks

Implement a daily task cap of 10 tasks per user, reset at 12am GMT, support for daily repeatable tasks, and ensure daily check-in is homepage-only.

## User Review Required

> [!IMPORTANT]
> - The 10-task cap will apply to both "Available" and "In Progress" states. Once a user hits 10 submissions in a day, other tasks will be hidden until the next GMT day.
> - "Repeatable" tasks will reappear in the "Available" list after the 12am GMT reset if they were completed the previous day.

## Proposed Changes

### Database Schema & Logic
- Add `is_repeatable` (boolean) to `public.tasks` table.
- Create a new table `daily_task_stats` (or similar) or a view to track daily completions per user, reset by GMT.
- Update `submit_task` and `record_video_watch` RPCs to:
    - Check the daily 10-task limit (considering GMT timezone).
    - Handle `is_repeatable` logic: if a task is repeatable, allow new submissions if the last one was on a previous GMT day.

### Admin Panel
- Update the Task Creation/Edit form to include the "Daily Repeatable" toggle.

### Frontend (Earn Page)
- Update the task fetching logic to only show up to 10 tasks if the user hasn't hit their limit, or show a "Daily Limit Reached" message.
- Verify that the Daily Check-in card is exclusively on the Dashboard and not the Earn page (it currently appears to be Dashboard-only).

### Security
- Update RLS policies and GRANTs for any new tables/columns.

## Technical Details
- Timezone handling: Use `AT TIME ZONE 'GMT'` in Postgres queries to ensure consistent 12am GMT resets regardless of server local time.
- Task visibility logic: `SELECT * FROM tasks WHERE ... AND (NOT EXISTS (completed today) OR is_repeatable) LIMIT (10 - count_today)`.
