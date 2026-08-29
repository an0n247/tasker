# Plan - Fix Overloaded Function Conflict in Redemptions Manager

The user is experiencing a database error when attempting to change a redemption status back to 'pending'. The error "Could not choose the best candidate function" indicates that PostgREST is confused between two versions of the `process_redemption_status_change` function. This typically happens when multiple functions with the same name exist in the `public` schema but with different argument signatures, and the call is ambiguous.

## Proposed Changes

### Database Logic
- Identify and consolidate the `process_redemption_status_change` functions.
- Drop the older version of the function that does not include `_rejection_reason`.
- Ensure the remaining function has a default value for `_rejection_reason` (e.g., `NULL` or empty string) to handle calls where it's not provided.
- Re-grant execute permissions to `authenticated` and `service_role`.

### Frontend Logic
- Verify `src/components/admin/RedemptionsManager.tsx` correctly passes the arguments to the RPC.
- Ensure the `rejection_reason` is passed as an empty string or `null` when setting a status to 'pending' or 'approved'.

## Technical Details
- The error "Could not choose the best candidate function" suggests that both `(uuid, text)` and `(uuid, text, text)` signatures exist.
- Supabase migrations will be used to clean up the duplicate function.
- The `process_redemption_status_change` function is responsible for:
    1. Updating the `status` and `rejection_reason` in the `redemptions` table.
    2. Handling point refunds if a status changes to 'rejected'.
    3. Re-deducting points if a previously 'rejected' reward is moved to another status.

## Verification Plan
- **Database Check**: Run a query to confirm only one version of the function exists.
- **Runtime Test**: Use the Admin Panel in the preview to:
    1. Approve a pending reward.
    2. Reject a reward (verify rejection reason is saved).
    3. Revert an approved/rejected reward back to 'pending' (verify the original error is gone).
    4. Move a rejected reward back to approved (verify points are re-deducted).
