# Centering Auth Page Layout

The user wants the authentication page content to be centered rather than aligned to the right. Currently, `src/routes/auth.tsx` uses a two-column grid on desktop, with the form in the first column and an image in the second. To "center" it, we will adjust the layout to prioritize the form's centered position or remove the side-by-side layout if that's what's causing the "right-side" feeling.

However, the user says "not to right side like that", which suggests the current two-column layout might be pushing the form to one side or the container itself isn't centered. Looking at the code, it's a `max-w-6xl` grid.

## Proposed Changes

### 1. Layout Adjustment in `src/routes/auth.tsx`
- Change the `lg:grid-cols-2` grid to a single column or adjust the grid container to ensure the form is more prominent/centered if the user prefers a single-column look.
- Alternatively, ensure the `max-w-6xl` container is truly centered (it currently has `justify-items-center` and `items-center`).
- If the user wants the form to be the central focus, we can switch to a single-column layout even on desktop, or make the form column wider and centered.

Given the request, I will:
1. Simplify the desktop layout to be a single centered column or adjust the existing two-column layout to feel more "centered" by perhaps removing the image or centering the whole block more aggressively.
2. The user specifically mentioned "align to center not to right side", so I will check if the grid is somehow visually weighted to the right.

### Technical Details
- Modify `src/routes/auth.tsx`:
    - Update the main wrapper div's classes.
    - Adjust the `grid-cols` configuration.
    - Ensure `justify-center` is consistently applied.

