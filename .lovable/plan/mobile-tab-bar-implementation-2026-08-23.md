# Mobile Tab Bar Implementation

Create a premium, modern mobile tab bar for authenticated users, providing quick access to key features with a high-end aesthetic.

## Proposed Changes

### Components

#### New `src/components/MobileTabBar.tsx`
- Create a floating, blur-background tab bar for mobile viewports.
- Aesthetic: Semi-transparent glassmorphism (`bg-card/80 backdrop-blur-lg`), rounded-t-3xl or floating pill, violet-600 primary accents.
- Icons: Dashboard, Earn, Redeem, Refer, Profile.
- Active states: Animated indicator or glow effect.

### Navigation Updates

#### `src/components/Navigation.tsx`
- Hide the sidebar and top-bar elements that are redundant with the new tab bar on mobile.
- Maintain the sidebar for desktop viewports.
- Keep the notifications and theme toggle (perhaps move them to the top bar or profile).

#### `src/routes/__root.tsx`
- Adjust main content padding-bottom on mobile to account for the tab bar height.
- Mount the `MobileTabBar` component globally but conditionally (only for authenticated, non-auth pages).

## Technical Details
- Use `lucide-react` for premium icons.
- Implement responsive visibility using Tailwind's `md:hidden`.
- Ensure fixed positioning (`fixed bottom-0 left-0 right-0`) with proper z-index.
- Add subtle haptic-like animations using Framer Motion (or simple CSS transitions).
