# Plan - Move Transactions link to Profile Dropdown

Relocate the "Transactions" navigation link from the sidebar menu to the user profile dropdown for a cleaner sidebar experience.

## User Review Required

> [!IMPORTANT]
> The "Transactions" link will no longer be visible in the main sidebar. It will be accessible by clicking the user avatar in the top right (desktop) or top bar (mobile).

## Proposed Changes

### Navigation

#### [src/components/Navigation.tsx](src/components/Navigation.tsx)
- Remove the "Transactions" entry from the `menuGroups` configuration used by the sidebar.
- Add a new "Points History" (Transactions) item to the `DropdownMenuContent` in the mobile view.
- Add a new "Points History" (Transactions) item to the `DropdownMenuContent` in the desktop view.
- Ensure consistent styling and icons (`History` icon) are used in the new locations.

## Verification Plan

### Automated Tests
- Run `lovable-exec test` if available (none specified in context, so will rely on manual/visual check).

### Manual Verification
- Log in to the application.
- Verify the "Transactions" link is **absent** from the sidebar on both desktop and mobile.
- Click the profile avatar (top right on desktop).
- Verify the "Points History" (or "Transactions") link is present and correctly navigates to `/transactions`.
- Shrink the browser to mobile view.
- Click the profile avatar in the mobile header.
- Verify the "Points History" link is present and works.
