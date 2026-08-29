# Plan: Optimize Auth Page for Mobile and Prevent Zoom/Scrolling

The goal is to ensure the login/signup page fits within a single viewport on mobile devices, avoids unnecessary vertical scrolling, and prevents browser auto-zoom by maintaining proper font sizes.

## Proposed Changes

### 1. Style Adjustments (src/routes/auth.tsx)
- Add `max-h-screen` and `overflow-y-auto` to the main container to ensure it respects the viewport height.
- Reduce vertical spacing and padding on mobile devices for the `Card` component and its children (`CardHeader`, `CardContent`, `TabsContent`).
- Standardize the card layout to be more compact on small screens.

### 2. Prevent Mobile Zoom (src/components/ui/input.tsx)
- Ensure all input fields use at least `16px` (`text-base`) font size to prevent iOS and Android browsers from auto-zooming on focus. (Already set to `text-base`, but will verify consistency).

### 3. Layout Optimization
- Adjust the "Abstract Background Shapes" in `auth.tsx` to use `fixed` or `absolute` positioning that doesn't expand the document height.

## Technical Details
- Use Tailwind responsive classes like `sm:p-8`, `p-4`, `space-y-2` (mobile) vs `space-y-4` (desktop).
- Ensure the verification screen also follows the "single page" constraint.

## Verification Plan
- Use Playwright to capture screenshots of the `/auth` route at `320px`, `375px`, and `414px` widths.
- Check for vertical overflow and ensure all critical elements (login button, tabs) are visible without excessive scrolling.
