# Plan - Rectify Mobile Header and Layout

The user is reporting that the mobile header is still problematic (based on the provided screenshot, it looks cramped or overlapping). I will refine the mobile top bar in `Navigation.tsx` and adjust the layout container in `__root.tsx` to ensure proper spacing and visibility.

## Proposed Changes

### Components

#### [src/components/Navigation.tsx](src/components/Navigation.tsx)
- Adjust the mobile top bar to have a more consistent height and padding.
- Ensure the profile avatar and notifications are properly spaced.
- Fix the `Avatar` styling to better match the design intent (consistent border and size).

#### [src/routes/__root.tsx](src/routes/__root.tsx)
- Refine the main content container's responsive padding.
- Ensure the background color is consistent across the entire viewport.

### Implementation details
- Use `h-16` or `h-20` for the mobile header consistently.
- Ensure the "Earn Pal" logo and hamburger menu don't overlap with the right-side icons.
- Add a subtle shadow or clearer border to separate the fixed header from the content.

## Verification Plan

### Automated Tests
- I will use Playwright to capture screenshots of the dashboard in a mobile viewport (`375x812`).
- Verify that the header elements (hamburger, logo, bell, profile) are all visible and correctly aligned.
- Verify that the main content (Welcome message, Balance card) is not hidden behind the header.

### Manual Verification
- Check the mobile preview to ensure the layout remains stable during scroll.
