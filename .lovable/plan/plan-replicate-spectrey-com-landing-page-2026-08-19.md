# Plan - Replicate spectrey.com Landing Page

Recreate the high-end SaaS landing page experience of spectrey.com for Earn Pal, focusing on the grid-based layout, typography, and premium interactive elements.

## User Review Required

> [!IMPORTANT]
> The target site uses a specific custom font ("helFont") and a unique grid-background aesthetic. I will use a combination of "Space Grotesk" for headings and "Inter" for body text to mimic the professional look, and implement the grid via CSS.

- **Theme Consistency**: Should we stick to the existing purple/blue Earn Pal palette, or shift closer to Spectrey's specific colors (Indigo/Slate)?
- **Sections**: I will implement the Hero, Unified Dashboard (Feature highlight), Scale/Growth, Feature Grid, FAQ, and Footer as seen on the reference. Are there any sections you'd like to omit?

## Proposed Changes

### Design & Assets
- Implement a global CSS grid background utility in `src/styles.css`.
- Add custom animation classes for the "floating" card effect seen in Spectrey's hero.
- Use Lucide icons that match the "unified control" vibe.

### Components
- **Navbar**: Update to match the glassmorphism and layout of the reference.
- **Hero**: Create a centered hero with a large headline, "badge" style announcement, and a central interactive dashboard preview.
- **Feature Cards**: Implement the "Unified Control" and "Limitless Growth" sections with high-quality mockups (simulated via CSS/Images).
- **FAQ**: Build a clean, accordion-based FAQ section.

### Routes
- **`src/routes/index.tsx`**: Complete overhaul to match the Spectrey structure.
- **`src/routes/__root.tsx`**: Ensure global layout supports the new full-width sections and header style.

## Technical Details
- Use Tailwind's `bg-grid` patterns (via arbitrary values or custom utilities).
- Implement `framer-motion` (if available) or standard Tailwind `animate-in` for section reveals.
- Maintain existing Auth logic (redirecting logged-in users to `/dashboard`).
