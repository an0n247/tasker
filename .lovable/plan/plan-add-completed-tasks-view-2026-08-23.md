# Plan - Add Completed Tasks View

Add a dedicated tab on the Earn page to view tasks that have already been completed, as they are currently hidden after completion.

## User Review Required

> [!IMPORTANT]
> The current system removes tasks from the "Earn" list immediately upon completion to keep the interface clean. This new section will act as a history log.

- **Completed Tab**: A new "Completed" option will be added to the category filter.
- **Task History**: This view will show all tasks marked as `verified` for the current user.

## Proposed Changes

### Logic updates
- Modify the `tasks` query in `src/routes/_authenticated.earn.tsx` to return both available and completed tasks (separately or filtered in-memory).
- Add "Completed" to the `categories` array in `EarnPage`.

### UI refinements
- Update the grid rendering to handle the "Completed" filter.
- Ensure the "Completed" tab displays tasks with a `verified` status badge.

## Technical Details

- **Database**: No schema changes required; uses existing `task_submissions` table where `status = 'verified'`.
- **Frontend**: Update `EarnPage` state to include the new category and update the `.filter()` logic in the `useQuery` or the `filteredTasks` memo.

## Progress Tracking
- [ ] Update category list and filter logic
- [ ] Modify task query to fetch completed tasks
- [ ] Implement the "Completed" tab view in the UI
