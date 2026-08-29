# Plan: Update Dashboard Layout and Site Title

The user wants the dashboard to match the layout shown in their reference video and to change the site title to "Paid Point". Based on the reference site (Paid Point Pulse) and typical dashboard layouts, I will refine the `Dashboard` component, update the navigation, and set the metadata.

## User Review Required

> [!IMPORTANT]
> I will update the dashboard layout to match the reference video provided. The title of the site will be updated to "Paid Point".

## Proposed Changes

### 1. Metadata and Site Title
- Update `src/routes/__root.tsx` to set the default site title to "Paid Point".
- Update `src/routes/index.tsx` `head()` function to set the page-specific title to "Dashboard | Paid Point".

### 2. Dashboard Layout (`src/routes/index.tsx`)
- Refine the grid layout and card designs to match the reference video.
- Ensure points balance, streaks, and referral progress are prominently displayed.
- Improve the "Recent Activity" and "Quick Tasks" sections for better visual hierarchy.

### 3. Navigation (`src/components/Navigation.tsx`)
- Ensure the branding in the navigation bar says "Paid Point".

## Technical Details

- **React components**: Update `src/routes/index.tsx` with refined Tailwind CSS classes for the dashboard UI.
- **TanStack Router**: Use the `head()` option in route definitions to manage SEO and titles.
- **Tailwind CSS**: Use standard project tokens for consistent styling.

## Next Steps
- Implement the layout changes in `src/routes/index.tsx`.
- Update the site title in `src/routes/__root.tsx` and route metadata.
