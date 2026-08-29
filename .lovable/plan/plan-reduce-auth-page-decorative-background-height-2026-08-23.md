# Plan - Reduce Auth Page Decorative Background Height

The user wants to reduce the height of the decorative background elements on the authentication page to ensure the page fits well on the screen without unnecessary scrolling or oversized visuals.

## Proposed Changes

### Styling
- **src/styles.css**:
    - Reduce the size of `.auth-shell::before` and `.auth-shell::after`.
    - Adjust their vertical offsets to be more contained within the viewport.
    - Set `overflow: hidden` (or `overflow-y: hidden`) on `.auth-shell` to prevent pseudo-elements from contributing to the total page height.

## Technical Details
- Change `::before` size from `15rem` to `10rem`.
- Change `::after` size from `12rem` to `8rem`.
- Adjust `top` and `bottom` positions to ensure they stay within the shell's boundaries or are clipped correctly.
- Ensure `overflow: hidden` is applied to `.auth-shell` to prevent these decorative elements from forcing vertical scrollbars.

## Verification Plan
- Inspect the `/auth` route in the preview.
- Verify that the decorative violet/secondary blobs are still visible but more compact.
- Confirm that the page does not have unnecessary vertical scrollbars on mobile and desktop when the content fits in the viewport.
