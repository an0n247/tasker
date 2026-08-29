# Plan - Task Card Responsive Width Adjustment

Optimize the task card widths for both desktop and mobile views to improve visual hierarchy and readability.

## Proposed Changes

### Task Card Components
- Identify the task card container in `src/routes/_authenticated.earn.tsx` and `src/routes/_authenticated.dashboard.tsx`.
- Adjust the `max-w` constraints for task cards:
    - On **desktop**: Remove the `max-w-4xl` constraint or increase it to allow for a "normal" full-width appearance within its grid column.
    - On **mobile**: Apply a slight horizontal padding or a slightly reduced `max-w` to prevent cards from touching the screen edges too tightly, giving them a more refined look.

### Technical Details
- In `src/routes/_authenticated.earn.tsx`:
    - Update the grid container `<div className="grid grid-cols-1 gap-6 sm:gap-6 md:grid-cols-2 lg:grid-cols-3 max-w-4xl mx-auto">`.
    - Change `max-w-4xl` to `max-w-6xl` or `max-w-full` for desktop.
    - Adjust mobile grid behavior: Ensure the `grid-cols-1` cards have a centered appearance with controlled width (e.g., `w-[92%] mx-auto`).
- In `src/routes/_authenticated.dashboard.tsx`:
    - Apply similar width adjustments to the "Featured Tasks" section.

## Verification Plan

### Automated Tests
- Use Playwright to capture screenshots of the Earn page and Dashboard on desktop (1280px) and mobile (375px).
- Verify that task cards are wider on desktop and have breathing space on mobile.

### Manual Verification
- Inspect the live preview at different breakpoints to ensure the cards look visually balanced.
- Confirm that literal instruction text in `src/routes/index.tsx` is preserved.
