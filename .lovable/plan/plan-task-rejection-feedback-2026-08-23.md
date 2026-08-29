# Plan - Task Rejection Feedback

Implement a system to show users the reason why their task submission was rejected by an admin.

## User Review Required

> [!IMPORTANT]
> The UI for rejected tasks will be added to the "Available" tab in the Earn Points page, allowing users to see why a task was rejected and potentially try again (depending on existing task constraints).

- Does the user want the ability to "re-submit" a rejected task, or just see the reason? *Assumption: User wants to see the reason on the task card or in a dedicated section.*

## Proposed Changes

### Backend (Lovable Cloud)

#### Database Schema
- Ensure `admin_note` and `verified_at` columns exist on `public.task_submissions`. (Already handled in SQL run).
- Update RLS policies to allow users to see their own `admin_note`.

### Frontend

#### Admin Panel
- Update `src/components/admin/TaskApprovals.tsx` to properly pass the `adminNote` state to the RPC call (it was already there but the state management could be cleaner).

#### Earn Page
- Update `src/routes/_authenticated.earn.tsx` to:
    - Include `rejected` status in the task fetching logic.
    - Add a "Rejected" tab or show rejected tasks in "Available" with a clear warning and the admin's reason.
    - Display the `admin_note` prominently on the task card when status is `rejected`.

#### Components
- Create a small `RejectionReasonAlert` component to display the feedback in a user-friendly way.

## Technical Details

- **RPC Update**: `verify_task_submission` updated to store the note.
- **Data Fetching**: The `tasks` query in `EarnPage` will now retrieve `admin_note` from the `task_submissions` join.
- **UI**: Use a destructive/warning style for rejection messages to differentiate them from pending or available tasks.

## Constraints & Considerations

- Tasks that are rejected might need to be "resettable" if the user is allowed to try again. Currently, the UI might need to allow deleting the submission or overwriting it.
