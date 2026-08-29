# Plan - Update Task Card Layout for Mobile

The user wants to display task cards in a 2-column grid on mobile devices (2 per line). Currently, the task cards are displayed in a single column on small screens.

## Proposed Changes

### 1. Update `src/routes/_authenticated.earn.tsx`
- Modify the grid layout classes in the `EarnPage` component to show 2 columns on mobile.
- Change `grid-cols-1` or default behavior to `grid-cols-2` for small screens.
- Ensure the cards look balanced with the new layout (potentially adjusting padding or font sizes if they become too cramped).

### 2. Update `src/routes/_authenticated.dashboard.tsx`
- Apply the same 2-column layout to "Featured Tasks" on mobile.

## Technical Details
- In Tailwind CSS, we will change `grid-cols-1` to `grid-cols-2` for the default (mobile) view.
- We will verify that labels, icons, and text inside the cards scale well or remain readable in the more compact 2-column mobile layout.
- The `gap` between cards might need adjustment (e.g., from `gap-6` to `gap-3` or `gap-4`) to maximize space.

## Verification
- Test the layout on a simulated mobile viewport (e.g., 375px width).
- Verify that task cards are side-by-side.
- Ensure no horizontal overflow occurs.
