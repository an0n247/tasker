# Plan - Mobile Tab Bar Refinement & Admin Link Placement

Refine the mobile tab bar to be more compact and integrated, and provide a logical placement for the Admin Panel link now that the sidebar is removed on mobile.

## User Review Required

> [!IMPORTANT]
> I will add the Admin Panel link (and other specialized roles like Moderator/Tasker) to the **Profile** page and the top-right **User Dropdown** menu on mobile. This keeps the tab bar focused on core user actions while ensuring admin tools are easily accessible for authorized users.

## Proposed Changes

### Mobile Tab Bar Refinement
#### [MobileTabBar.tsx](src/components/MobileTabBar.tsx)
- Reduce overall height and padding of the floating bar.
- Adjust icon sizes from `h-6 w-6` to `h-5 w-5` for a tighter look.
- Optimize the spacing between tabs and the scale animation.
- Move from `bottom-6` to `bottom-4` to sit slightly lower while remaining accessible.

### Global Layout & Navigation
#### [Navigation.tsx](src/components/Navigation.tsx)
- Add conditional Admin/Moderator/Tasker links to the mobile user dropdown menu (top right).
- Ensure the dropdown menu is the primary access point for administrative functions on mobile.

#### [profile.tsx](src/routes/_authenticated.profile.tsx)
- Add a "Platform Management" section to the Profile page, visible only to users with Admin, Moderator, or Tasker roles.
- This provides a secondary, high-visibility entry point for admin tools.

#### [__root.tsx](src/routes/__root.tsx)
- Slightly reduce the bottom padding (`pb-24` to `pb-20`) on mobile to account for the more compact tab bar.

## Technical Details
- Use `useAuth` hook in `MobileTabBar` if needed for future dynamic tabs, but for now, the static list is sufficient as admin tools move to the profile/dropdown.
- Maintain glassmorphic design and accessibility targets (touch targets will remain within recommended limits).
- Role-based visibility logic will use existing RPC calls or `useAuth` status.
