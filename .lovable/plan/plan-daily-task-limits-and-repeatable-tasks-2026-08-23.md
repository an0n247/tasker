# Plan: Daily Task Limits and Repeatable Tasks

Implement a 10-task daily cap per user, support daily repeatable tasks, and optimize the UI by removing duplicate streak cards from the Earn page.

## User-Facing Changes
- **Daily Limit**: Users will be restricted to completing 10 tasks per 24-hour period (resetting at 00:00 GMT).
- **Daily Repeatable Tasks**: Certain tasks (like social interactions) can now be completed once every day for recurring points.
- **Clean Earn Page**: The "Daily Streak" section will be removed from the Earn page to avoid clutter, remaining accessible on the Dashboard.
- **Improved Feedback**: Users will receive clear notifications when they reach their daily task limit.

## Technical Details
- **Database Schema**:
  - Add `is_repeatable` column to `public.tasks` table.
  - Create `public.user_daily_task_counts` view to calculate daily completions using GMT timestamps.
- **Hardened RPCs**:
  - Update `submit_task` to check the daily limit and handle `is_repeatable` reset logic.
  - Update `record_video_watch` to enforce the 10-task cap upon completion.
- **Frontend Updates**:
  - Modify `src/routes/_authenticated.earn.tsx` to remove the Daily Streak card.
  - Add daily limit checks in the Task submission flow to disable buttons and show appropriate tooltips.

## Security & Reliability
- Enforce limits via `SECURITY DEFINER` server-side functions to prevent client-side bypass.
- Use GMT consistently for all resets to ensure predictable behavior for a global user base.
