# Plan: Linked Notifications to Transactions

Allow users to click notifications to view associated transaction details, improving navigation and visibility.

## User Review Required

> [!IMPORTANT]
> - Clicking a notification will show a detailed transaction toast (matching the behavior on the Transactions page).
> - For notifications not linked to a specific transaction, clicking will navigate the user to the Transactions page.

## Proposed Changes

### Database & Schema
- Add a `transaction_id` (UUID, nullable) column to the `notifications` table.
- Update the `notify_on_points_transaction` trigger function to include the `NEW.id` (the transaction ID) in the `transaction_id` column of the created notification.

### Component Enhancements
#### Notifications Popover
- Update `src/components/NotificationsPopover.tsx`:
    - Fetch the new `transaction_id` field.
    - Implement a `handleNotificationClick` function that:
        - If `transaction_id` exists, fetches the transaction details and displays them in a toast.
        - If no `transaction_id` exists but the type is 'points' or 'reward', navigate to the `/transactions` route.
        - Marks the notification as read.
    - Apply a visual text edit to a neutral anchor if present (as requested by the system instructions).

#### Shared Transaction Details
- Extract the transaction detail toast logic from `src/routes/_authenticated.transactions.tsx` into a reusable utility to ensure UI consistency.

## Technical Details
- **Migration**: 
  ```sql
  ALTER TABLE public.notifications ADD COLUMN transaction_id UUID REFERENCES public.points_transactions(id);
  CREATE OR REPLACE FUNCTION public.notify_on_points_transaction() ... (updated to include transaction_id)
  ```
- **Frontend**: Use `useNavigate` from TanStack Router for navigation and `supabase` client for fetching single transactions.

## Verification Plan
1. **Manual Test**: Perform an action that grants points (e.g., daily claim).
2. **Notification Check**: Click the generated notification in the popover.
3. **UI Validation**: Confirm the transaction details toast appears with correct data.
4. **Navigation Check**: Ensure notifications without IDs correctly redirect to the transactions history.
