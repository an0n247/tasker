# Plan - Mobile Dashboard Layout Optimization

Update the mobile dashboard to show "Lifetime Referrals" and "Invite your friend" cards in a single row for better space utilization.

## Proposed Changes

### Dashboard Component
- Locate the "Quick Stats & Promo" section in `src/routes/_authenticated.dashboard.tsx`.
- Refactor the grid layout for mobile breakpoints to display these two cards side-by-side.
- Ensure proper spacing and typography scaling so content remains legible in the tighter horizontal space.

### Technical Details
- Change `grid-cols-1` to `grid-cols-2` on the container for stats/promo cards in the mobile view (`sm` and below).
- Adjust padding and font sizes within the cards if necessary to prevent text wrapping issues.
- Maintain `lg:col-span-4` for desktop layout to keep the sidebar-like appearance.

## Verification Plan

### Automated Tests
- Run Playwright script to verify `grid-cols-2` is applied to the stats container on mobile viewports.
- Capture screenshots at `375px` width to confirm visual alignment.

### Manual Verification
- Inspect the mobile preview to ensure the "Lifetime Referrals" card and "Invite your friend" card are correctly aligned in a single row.
- Check that the "Get Referral Link" button within the invite card remains usable.
