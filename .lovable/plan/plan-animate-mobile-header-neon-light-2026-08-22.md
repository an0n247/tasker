# Plan: Animate Mobile Header Neon Light

The goal is to add a pulsing animation to the neon light effect on the mobile header's rounded edges.

## Technical Details

- Define a custom keyframes animation `neon-pulse` in `src/styles.css` that varies the `box-shadow` spread and opacity.
- Create a utility class `.animate-neon-pulse` in `src/styles.css` that applies this animation specifically to the `::after` pseudo-element (which carries the neon light effect).
- Apply the `.animate-neon-pulse` class to the header containers in `src/components/Navigation.tsx` where the neon light was previously added.
- Ensure the animation only triggers on mobile or uses the `md:after:hidden` logic already in place to remain clean on desktop.

## Changes

### Styling
- Add `neon-pulse` keyframes and `.animate-neon-pulse` utility to `src/styles.css`.

### Components
- Update `src/components/Navigation.tsx` to include `animate-neon-pulse` in the class strings for:
    - The landing page mobile navigation header.
    - The authenticated mobile top bar.
