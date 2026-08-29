# Plan: Auth Page Header Implementation

The user wants the curved edge header to also show on the authentication page. Currently, `src/components/Navigation.tsx` explicitly returns `null` for the auth page.

## Proposed Changes

### `src/components/Navigation.tsx`
- Remove the early return `if (isAuthPage) return null;`.
- Update the logic to render the curved header (similar to the landing page style) when `isAuthPage` is true.
- Ensure the header links are appropriate for the auth page (perhaps simplified or consistent with the landing page).

### `src/routes/auth.tsx`
- Remove the manual `ThemeToggle` in the top right to avoid duplication with the one in the header.
- Adjust padding-top to account for the fixed floating header.

## Technical Details
- The current floating header in `Navigation.tsx` uses `fixed top-2 left-2 right-2 z-50`.
- We will reuse the landing page's `nav` structure but ensure it doesn't conflict with the `AuthPage` layout.

## Verification Plan
- Navigate to `/auth` and verify the floating rounded header is visible.
- Check responsiveness on mobile and desktop.
- Verify the `ThemeToggle` works and isn't duplicated.
