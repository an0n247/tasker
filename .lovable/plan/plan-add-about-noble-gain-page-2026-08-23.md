# Plan: Add "About Noble Gain" page

The user wants a new page that explains the mission, brand story, and key features of Noble Gain, using the new branding assets (deep green/gold palette).

## Proposed Changes

### 1. Create the new "About" route
- Create `src/routes/about.tsx`.
- Design a high-fidelity, branded layout using `framer-motion` for reveal animations.
- Content sections:
    - **Mission Statement**: Empowering users to turn digital time into meaningful value.
    - **Brand Story**: Transition from simple task-earning to a premium rewards community.
    - **Key Features**: Highlight transparency, security, and the referral network.
- Visuals: Use the gold circle logo assets, deep green backgrounds, and gold accents.

### 2. Update Navigation
- Add the "About" link to `src/components/Navigation.tsx` in both desktop and mobile menus.
- Add the "About" link to the footer in `src/routes/index.tsx`.

### 3. Update SEO and Sitemap
- Ensure the new route has appropriate head metadata (title, description, OG image).
- Add the route to `src/routes/api/public/sitemap.tsx` and `src/routes/api/public/robots.tsx`.

## Technical Details

### `src/routes/about.tsx`
- Layout: Glassmorphic cards, typography using `font-black` and tight letter spacing.
- Components: `Accordion` for detailed feature breakdowns, `Button` for CTA to sign up.

### `src/routes/api/public/sitemap.tsx`
- Add `/about` to the `routes` array.

### `src/routes/api/public/robots.tsx`
- Ensure `/about` is allowed.

## Verification Plan

### Automated Checks
- Verify the file exists and compiles without errors.
- Check that the navigation links to the correct path.

### Manual Verification
- Navigate to `/about` in the preview.
- Toggle dark mode to ensure the branding remains legible and premium-looking.
- Check mobile responsiveness of the new layout.
