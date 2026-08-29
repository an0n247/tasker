# Plan - Task Management Configuration in Admin Panel

Add a configuration section to the Admin Panel allowing administrators to set the daily task limit and manage repeatable tasks.

## User Review Required

> [!IMPORTANT]
> The daily task limit will be global for all users. Repeatable tasks can be completed once every 24 hours (GMT).

- No critical questions identified.

## Proposed Changes

### Database Settings
- Add a new key `daily_task_limit` to the `app_settings` table (if not already present via seed).
- Ensure the `tasks` table has the `is_repeatable` column (already exists based on `types.ts`).

### Admin UI Enhancements
#### Platform Settings
- Update `src/components/admin/PlatformSettings.tsx` to include a new "Task Configuration" section.
- Add an input field for `daily_task_limit`.

#### Task Management
- Update `src/components/admin/TasksManager.tsx` to include a "Repeatable Task" toggle in the Add/Edit task dialog.
- Ensure the repeatable status is visible in the task list.

## Technical Details

### Backend Components
- **`app_settings`**: Key `daily_task_limit` with a default numeric value (e.g., 10).
- **`tasks`**: Boolean column `is_repeatable`.

### Frontend Components
- **`PlatformSettings`**:
    - Add logic to fetch and update `daily_task_limit`.
    - Use existing `updateMutation` pattern.
- **`TasksManager`**:
    - Update `formData` and dialog UI to handle `is_repeatable`.
    - Update `upsertTaskMutation` to send the new field.
