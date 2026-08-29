# Plan - Refine Desktop Navigation

Remove "Profile" and "Settings" links from the main desktop navigation bar since they already exist as standalone icons in the header.

## Proposed Changes

### Navigation Component
- Modify the desktop navigation rendering in `src/components/Navigation.tsx` to filter out "Profile" and "Settings" from the horizontal link list.
- Ensure these items remain available in the mobile dropdown menu where they are still needed for navigation.

## Technical Details
- In `src/components/Navigation.tsx`, update the desktop navigation `map` call to filter `navItems`.
- Specifically, check for `item.name !== "Profile" && item.name !== "Settings"` before rendering the links in the `md:flex` container.
