# Plan: Implementation of "In Progress" Tasks and Admin Task Verification

This plan adds an "In Progress" tab for users to track tasks awaiting verification and an admin interface to review and approve/reject these tasks.

## Proposed Changes

### Database Schema Changes
- **Migration**: Create a new migration to handle task verification logic.
- **RPC**: Create a `verify_task_submission` RPC for admins to approve or reject tasks.
- **Grants**: Ensure proper permissions for the new RPC.

### User Interface - Earn Page (`src/routes/_authenticated.earn.tsx`)
- **New State**: Add `in_progress` to the `activeStatus` state.
- **Tab Update**: Insert an "In Progress" tab between "Available" and "Completed".
- **Filter Logic**: Update `filteredTasks` to include a filter for `status === 'pending'` when "In Progress" is active.
- **Unified View**: Ensure "In Progress" and "Completed" views ignore category filters as requested.

### Admin Interface - Admin Panel (`src/components/AdminPanel.tsx` & `src/components/admin/TaskApprovals.tsx`)
- **New Component**: Create `TaskApprovals.tsx` to list all `pending` submissions.
- **New Tab**: Add a "Verifications" tab to the admin panel.
- **Actions**: Provide "Approve" and "Reject" buttons for each pending submission.

## Technical Details

### New RPC: `verify_task_submission`
```sql
CREATE OR REPLACE FUNCTION public.verify_task_submission(
    _submission_id uuid,
    _approve boolean,
    _admin_note text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Security check
    IF NOT public.has_role(auth.uid(), 'admin') AND NOT public.has_role(auth.uid(), 'moderator') THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF _approve THEN
        UPDATE public.task_submissions
        SET status = 'verified', 
            verified_at = now(),
            admin_note = _admin_note
        WHERE id = _submission_id;
        
        -- Logic to award points is usually handled by triggers on task_submissions update
    ELSE
        UPDATE public.task_submissions
        SET status = 'rejected', 
            admin_note = _admin_note
        WHERE id = _submission_id;
    END IF;

    RETURN json_build_object('success', true);
END;
$$;
```

### UI Refinement
- **Earn Page**:
  - `activeStatus` enum: `"available" | "in_progress" | "completed"`
  - `filteredTasks` will check `t.status === 'pending'` for `in_progress`.
- **Admin Panel**:
  - Register `TaskApprovals` in `AdminPanel.tsx`.
  - Add `ShieldCheck` icon for the "Verifications" tab.
