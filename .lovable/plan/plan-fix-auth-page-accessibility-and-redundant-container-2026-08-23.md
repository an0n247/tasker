# Plan: Fix Auth Page Accessibility and Redundant Container

The user reported that the auth card and decorative background appear to be inside a redundant "white container" that boxed the whole page, affecting accessibility. My investigation shows that `RootComponent` in `src/routes/__root.tsx` wraps all content (including the `/auth` route) in a `div` with `bg-background`, which creates a light-colored surface behind the dark-themed auth shell.

## Proposed Changes

### 1. Refactor `src/routes/__root.tsx`
- Conditionally remove the global `div` wrapper's background and padding for the `/auth` route.
- This ensures the `auth-shell` in `src/routes/auth.tsx` (which already has `bg-background` and full-screen layout) becomes the true root-level container for that route.

### 2. Update `src/routes/auth.tsx`
- Ensure the `auth-shell` truly fills the entire viewport without interference from parent containers.
- Verify the decorative elements (`::before`, `::after`) are not clipped.

### 3. Global Style Refinement (`src/styles.css`)
- Remove `overflow: hidden` from `html, body` to ensure standard accessibility and scroll behavior, as previously identified.

## Technical Details
- In `src/routes/__root.tsx`, use `location.pathname === "/auth"` to toggle classes on the main wrapper.
- Ensure `ThemeToggle` and other global components don't introduce unexpected layout shifts.
