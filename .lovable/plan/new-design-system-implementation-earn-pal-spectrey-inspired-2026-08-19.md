# New Design System Implementation: Earn Pal (Spectrey-inspired)

The goal is to overhaul the visual identity of Earn Pal based on the provided design reference. This includes adopting a new color palette, refined card styles, specific spacing patterns, and a cleaner sidebar-based navigation for authenticated users.

## Design Tokens

- **Primary Color:** Violet-600 (`oklch(0.606 0.25 273.428)`)
- **Background:** Off-white (`#F8F9FB` / `oklch(0.98 0.005 247.858)`)
- **Labels/Muted:** Gray-400 (`oklch(0.7 0.01 247.858)`)
- **Typography:** Sans-serif (Inter) for all elements.
- **Radii:** Rounded-2xl (1rem) for main components, Rounded-xl for smaller elements.

## User Experience Changes

### Global Styling (`src/styles.css`)
- Update CSS variables in `:root` and `.dark` blocks to match the new palette.
- Set global background to the off-white color.
- Standardize on Inter font weights (Normal/Medium for body, Bold for emphasis).

### Layout & Navigation (`src/components/Navigation.tsx`)
- Implement a persistent Sidebar for authenticated routes (Dashboard, Earn, Refer, etc.).
- The sidebar will feature:
  - Main logo area with a violet coin icon.
  - Categorized menu items (Main Menu, Account).
  - User profile summary and Logout at the bottom.
- Add a top header bar for mobile (hamburger menu) and desktop (notifications, balance pill).

### Component Styles (`src/components/ui/card.tsx`)
- Update the base Card component to use `rounded-2xl` and a subtle shadow-sm.
- Remove heavy borders, preferring clean white backgrounds on the off-white surface.

### Page Overhauls
- **Dashboard (`src/routes/dashboard.tsx`):** Replace the current grid with the new layout, using the "Earnings Growth" hero card and refined balance tracking.
- **Profile (`src/routes/profile.tsx`):** Re-style the profile card to match the minimal sidebar aesthetic.
- **Referral (`src/routes/refer.tsx`):** Clean up the tabs and statistics cards.
- **Auth (`src/routes/auth.tsx`):** Modernize the sign-in/up cards with the violet primary theme.

## Technical Details

- **Tailwind v4 (@theme):** Variables will be mapped in the CSS file.
- **Lucide Icons:** Icons will be updated to match the reference (e.g., using `strokeWidth={1.8}`).
- **Responsive Design:** Sidebar will be off-canvas on mobile with a semi-transparent overlay.
