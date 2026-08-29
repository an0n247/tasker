# Plan - Mobile Layout and Navigation Fixes

The user reported layout issues on mobile (sidebar pushing content or misaligned) and a placeholder "?" icon where the user profile icon should be in the header.

## Proposed Changes

### 1. Navigation Enhancements
- Update `src/components/Navigation.tsx` to fix the mobile top bar and sidebar.
- Replace the placeholder "?" in `AvatarFallback` with a proper `User` icon or consistent initials.
- Ensure the mobile top bar correctly shows the user's avatar instead of a placeholder.
- Refine the mobile overlay to ensure it doesn't "push" content but stays as a proper overlay.

### 2. Layout Consistency
- Verify `src/routes/__root.tsx` main content padding to ensure it matches the sidebar width and top bar height on all devices.
- Adjust `md:pl-72` and `pt-16` logic in `RootComponent` to be more robust.

### 3. Profile Page Refinement
- Ensure the profile page uses the latest `User` profile data consistently.

## Technical Details

### Navigation (`src/components/Navigation.tsx`)
- Modify `AvatarFallback` in both mobile and sidebar views to use `User` icon from `lucide-react` if no initials are available.
- Check the `Avatar` implementation in the mobile header (line 182-187) and sidebar (line 146-151).

### Root Layout (`src/routes/__root.tsx`)
- Review the `main` tag's `className` logic to ensure `md:pl-72` matches the `aside` width in `Navigation.tsx`.

## User Review Required

> [!IMPORTANT]
> I will replace the "?" icon with the user's initials or a generic user silhouette icon.
