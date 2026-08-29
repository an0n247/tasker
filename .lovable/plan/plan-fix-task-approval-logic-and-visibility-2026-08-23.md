# Plan - Fix Task Approval Logic and Visibility

The user is reporting two main issues:
1. Tasks set for "instant rewards" (verification not required) are still waiting for approval.
2. These tasks do not appear in the admin verification tab.

## Diagnosis

1.  **Instant rewards waiting for approval**:
    - The `submit_task` RPC was updated in a recent migration (`20260823020237_959a522b-0d1f-46c0-8909-7ed0f296b8e5.sql`) to handle daily limits and repeatability.
    - This update inadvertently removed the conditional logic that awards "verified" status immediately if `verification_required` is false. It now defaults all non-video submissions to `pending`.
2.  **Tasks not showing in admin**:
    - A previous hardening migration (`20260823020535_c45b9949-afd1-4fac-adc8-84afb917c371.sql`) revoked `EXECUTE` on `verify_task_submission` from `PUBLIC` and only granted it to `service_role`.
    - However, the admin panel calls this RPC via the authenticated user's client. The `authenticated` role needs `EXECUTE` permission (gated by internal role checks).
    - RLS policies on `task_submissions` are correct for admins, so the visibility issue in the UI is likely a combination of the RPC permission error and the fact that "verified" tasks (which shouldn't be pending) are being filtered out of the "Pending" view.

## Proposed Changes

### Database (Supabase)

1.  **Update `submit_task` RPC**:
    - Restore logic to check `tasks.verification_required`.
    - If `false`, insert with status `verified`.
    - If `true`, insert with status `pending`.
    - Ensure daily limits and repeatability checks are preserved.
2.  **Fix Permissions**:
    - Grant `EXECUTE` on `verify_task_submission` to the `authenticated` role.
    - (The function already uses `SECURITY DEFINER` and internal role checks to ensure only admins/moderators can process verifications).

### Frontend

1.  **Audit `TasksManager`**:
    - Ensure the "Verification Required" toggle correctly updates the `verification_required` column in the database. (The current implementation seems correct but I will verify).

## Verification Plan

### Automated Tests
- None available for RPCs.

### Manual Verification
1.  **User Flow**:
    - Create a task with "Instant Reward" (Verification Required = OFF).
    - Submit the task as a user.
    - Verify points are awarded immediately and status is `verified`.
    - Create a task with "Verification Required" = ON.
    - Submit as a user.
    - Verify status is `pending` and no points are awarded yet.
2.  **Admin Flow**:
    - Log in as admin.
    - Navigate to Admin -> Verifications.
    - Verify the "pending" task appears.
    - Approve/Reject the task and verify the RPC executes successfully (no permission error).
