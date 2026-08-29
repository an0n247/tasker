# Plan: Update Admin Redemption Actions

The user wants to replace the search icon in the "Actions" column of the Redemptions tab with "Approve" and "Reject" buttons, matching the design for pending redemptions but applied to all statuses (or specifically ensuring they are visible for status changes). The screenshot shows the "search" icon being displayed even for approved/rejected states, which the user wants to change to the action buttons.

## User Review Required

> [!IMPORTANT]
> The action buttons will now be visible for all redemptions in the list, allowing you to re-approve or re-reject if needed, replacing the "search" icon currently shown for processed redemptions.

## Proposed Changes

### Admin UI

#### [RedemptionsManager.tsx](src/components/admin/RedemptionsManager.tsx)
- Remove the conditional rendering that shows a search icon for non-pending redemptions.
- Consistently show the "Approve" (Check) and "Reject" (X) buttons with their confirmation dialogs for every row.
- Ensure the layout remains clean and responsive in the table.

## Technical Details

- Simplify the `Actions` cell logic to always render the `AlertDialog` blocks for both Approve and Reject.
- Remove the `Search` icon button that was previously used for "Review Details" on processed redemptions.
- Maintain consistency with the existing `AlertDialog` patterns for security and confirmation.
