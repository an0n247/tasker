# Plan: Fix Task Verification Visibility for Admins

The user reported that task submissions are not appearing in the Admin Verification tab. This is likely due to restrictive Row-Level Security (RLS) policies on the `task_submissions` table, which currently only allow users to see their own submissions.

## Proposed Changes

### Database (Supabase)

1.  **Update RLS Policies for `task_submissions`**:
    *   Add a new policy "Admins and moderators can view all pending submissions" to allow users with 'admin' or 'moderator' roles to select rows from the `task_submissions` table.
    *   Ensure the `has_role` function is used to verify permissions securely.

### Implementation Details

#### SQL Migration
```sql
-- Add policy for admins and moderators to view all submissions
CREATE POLICY "Admins and moderators can view all submissions"
ON public.task_submissions FOR SELECT
TO authenticated
USING (
    public.has_role(auth.uid(), 'admin') 
    OR 
    public.has_role(auth.uid(), 'moderator')
    OR
    public.has_role(auth.uid(), 'tasker')
);

-- Ensure grants are sufficient
GRANT SELECT ON public.task_submissions TO authenticated;
```

## Verification Plan

### Automated Tests
*   Verify that the SQL migration applies correctly.
*   (If possible) Run a test query as an admin user to ensure pending submissions are returned.

### Manual Verification
*   Submit a task as a regular user (ensure it requires verification).
*   Log in as an admin or moderator.
*   Navigate to the Admin Panel > Verifications tab.
*   Confirm the submission is visible in the list.
