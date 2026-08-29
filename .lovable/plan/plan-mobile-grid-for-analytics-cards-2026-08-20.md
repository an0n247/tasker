# Plan - Mobile Grid for Analytics Cards

The user wants the analytics cards to be displayed in a 2-column grid on mobile devices. Currently, they likely stack in a single column or use a different grid configuration.

## Proposed Changes

### UI Components

#### Admin Panel Statistics
- Modify `src/components/AdminPanel.tsx`: Update the stats overview grid from `grid-cols-2` (on `md`) and implicit `grid-cols-1` (on mobile) to `grid-cols-2` by default to ensure 2 cards per line on mobile.

#### Analytics View Funnel Cards
- Modify `src/components/admin/AnalyticsView.tsx`: Update the funnel cards grid from `md:grid-cols-3` (on `md`) and implicit `grid-cols-1` (on mobile) to `grid-cols-2` by default.

## Technical Details
- Change `grid-cols-2 md:grid-cols-2 lg:grid-cols-4` in `AdminPanel.tsx` to ensure mobile has 2 columns.
- Change `grid gap-4 md:grid-cols-3` to `grid gap-4 grid-cols-2 md:grid-cols-3` in `AnalyticsView.tsx`.
- Adjust font sizes or padding if cards become too cramped on very small viewports (e.g., iPhone SE), though the current design uses `text-[10px]` and `text-2xl` which should fit.

## Verification Plan
- Simulate mobile viewport (375px width).
- Verify `AdminPanel` stats overview shows 2 cards per row.
- Verify `AnalyticsView` funnel cards show 2 cards per row.
