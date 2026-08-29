# Plan - Optimize Auth Page Scrollability

The user wants the authentication page to have a fixed height (no overall page scroll) while allowing only the signup form to scroll if its content exceeds the container's height. This will improve the UX on smaller screens where the signup form might be too tall for the viewport.

## Proposed Changes

### 1. Update Layout and Scroll Behavior

- Modify the authentication page container to ensure it maintains a fixed height (using `h-screen` or `min-h-[100dvh]`).
- Adjust the `CardContent` or `TabsContent` to handle internal scrolling for the signup form.
- Use `overflow-y-auto` on the scrollable container and `max-h` to limit its size relative to the card.

### 2. Implementation Details

- In `src/routes/auth.tsx`:
    - Ensure the main container has `overflow-hidden`.
    - Wrap the signup form in a container with `max-h-[60vh] md:max-h-[50vh]` and `overflow-y-auto`.
    - Apply custom scrollbar styling for a cleaner look.

## Technical Details

- **File**: `src/routes/auth.tsx`
- **Classes**: 
    - `max-h-[calc(100dvh-200px)]` for the form container to ensure it stays within the card.
    - `overflow-y-auto` for internal scrolling.
    - `scrollbar-hide` or custom utility if needed, but standard `overflow-y-auto` with Tailwind's default scrollbar is usually sufficient.

## Verification Plan

- **Manual Verification**:
    - Open the signup tab on a mobile-sized viewport.
    - Confirm the page itself does not scroll.
    - Confirm the signup form can be scrolled if the fields don't fit.
    - Confirm the login tab remains clean and fits without unnecessary scrolling.
