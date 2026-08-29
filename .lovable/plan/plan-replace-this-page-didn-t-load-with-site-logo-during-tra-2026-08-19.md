# Plan - Replace "This page didn't load" with site logo during transitions

The goal is to replace the generic "This page didn't load" error/loading UI with a branded logo animation or placeholder, particularly during redirects or session hydration.

## Proposed Changes

### Root Route Layout
- Modify `src/routes/__root.tsx`:
  - Update `ErrorComponent` to display the "Earn Pal" logo (Coins icon + Text) instead of the generic "This page didn't load" text.
  - Add a dedicated loading fallback to the root `Outlet` or `Suspense` boundary if applicable, ensuring the logo is shown during initial session checks.

### Styling & Components
- Ensure the logo uses the primary color (Violet-600) and is centered.
- Add a subtle pulse animation to the loading state.

## Technical Details
- The current `ErrorComponent` in `__root.tsx` is being triggered potentially during session redirects or hydration mismatches.
- I will reuse the `Coins` icon from `lucide-react` which is already the branded icon for Earn Pal.
- I will ensure the transition is smooth by using Tailwind's `animate-pulse`.

## Verification Plan
- Manually trigger a logout and login to observe the transition.
- Use Playwright to simulate a slow network connection and verify the branded loading/error state appears.
- Check mobile and desktop viewports to ensure the logo is perfectly centered.
