# Plan: Implement Real Activity Signals for Dashboard Cards

The goal is to replace hardcoded percentage signals (e.g., "+12% from last week") on the user and admin dashboards with real values derived from the database.

## User Dashboard (`src/routes/_authenticated.dashboard.tsx`)
- **Metric**: Balance Trend (+12% from last week).
- **Implementation**:
    - Add a `useQuery` to calculate the percentage change in points earned this week vs. last week.
    - Query `points_transactions` for the current user.
    - Compare `sum(amount)` where `type = 'earn'` for the last 7 days vs. the 7 days before that.
    - Update the UI to display this calculated percentage.

## Admin Dashboard (`src/components/AdminPanel.tsx`)
- **Metrics**: Total Users trend (+12%), Points Issued trend (+8%), Points Redeemed trend (+5%), Redemptions trend (-2%).
- **Implementation**:
    - Update the `adminStats` query to fetch historical counts/sums for comparison.
    - **Total Users**: Compare count of `profiles` created in the last 30 days vs. previous 30 days.
    - **Points Issued**: Compare `sum(amount)` of positive `points_transactions` in the last 30 days vs. previous 30 days.
    - **Points Redeemed**: Compare `sum(amount)` of negative `points_transactions` in the last 30 days vs. previous 30 days.
    - **Redemptions**: Compare count of `redemptions` in the last 30 days vs. previous 30 days.
    - Replace the hardcoded `statCards` trends with these calculated values.

## Technical Details
- Use `date-fns` (or native JS `Date`) to calculate time ranges (e.g., `new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)`).
- Handle edge cases where the previous period had 0 activity (division by zero) by defaulting to 100% or 0% as appropriate.
- Ensure the trends update automatically when data changes (handled by TanStack Query invalidation).
