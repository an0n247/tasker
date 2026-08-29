# Plan: Swap Auth Page Layout

The user wants to swap the desktop layout of the authentication page so that the login/signup form is on the left and the mockup image is on the right.

## Technical Details

### 1. Update Auth Page Layout
- Modify `src/routes/auth.tsx`.
- Currently, the mockup image div is before the auth card div in the grid.
- I will swap their order in the JSX to move the form to the left and the image to the right on desktop (`lg` viewports).
- I will also update the animation classes (`slide-in-from-left` to `slide-in-from-right` for the image) to ensure the visual transition feels correct.

### 2. Verification
- Use a Playwright script to capture a screenshot of the auth page on a desktop viewport to confirm the new layout.
