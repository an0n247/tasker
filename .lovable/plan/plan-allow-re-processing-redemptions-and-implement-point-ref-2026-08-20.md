# Plan: Allow Re-processing Redemptions and Implement Point Refunds on Rejection

The user wants to be able to change the status of a redemption even after an action has been taken (Approve/Reject). Additionally, if a redemption is rejected, the points charged should be refunded to the user's balance, and this refund should appear in their transaction history.

## User Review Required

> [!IMPORTANT]
> - Rejecting a redemption will now automatically refund the points to the user.
> - If you change an "Approved" redemption to "Rejected", the points will be refunded.
> - If you change a "Rejected" redemption back to "Approved", the system will need to re-deduct points. **Note:** If the user has spent their refunded points in the meantime, this might fail or result in a negative balance depending on current constraints. I will implement a check for this.

## Proposed Changes

### Database Logic (Supabase Migrations)

#### [New Migration: Handle Redemption Status Changes and Refunds]
- Create a new database function `handle_redemption_status_change` that:
    - Takes `redemption_id` and `new_status`.
    - Detects transitions between `pending`, `approved`, and `rejected`.
    - **Transition to Rejected:** If the old status was not `rejected`, insert a positive `points_transaction` to refund the cost and update the user's `points_balance`.
    - **Transition from Rejected to Approved/Pending:** If the old status was `rejected`, insert a negative `points_transaction` to re-deduct the cost (checking for sufficient balance).
    - Updates the `redemptions` table status.
    - Adds an `admin_audit_log` entry.

### Admin UI

#### [RedemptionsManager.tsx](src/components/admin/RedemptionsManager.tsx)
- Update `updateStatusMutation` to call the new database function (via RPC or by handling the logic inside the mutation if kept client-side, though server-side is safer for balance integrity).
- Ensure the UI correctly reflects the ability to change status even if already processed.
- Add success/error toasts that specifically mention the refund status.

## Technical Details

- The refund transaction will have a description like `Refund: Rejected [Reward Title] redemption`.
- I will use a database transaction (RPC) to ensure the status update and point refund/deduction happen atomically.
- I'll check `supabase/migrations/20260819000001_sync_points_balance.sql` to ensure my manual balance updates don't conflict with any existing triggers.
