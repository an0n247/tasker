# Plan - Fix Welcome and Onboarding Modals

The user is reporting that a "welcome to earnpal screen pop up" is showing on every click. Based on the codebase, there are two components that could be responsible: `WelcomeBonusModal.tsx` and `Onboarding.tsx`. Both need to be hardened to ensure they only show once per user and are fully responsive on mobile.

## Proposed Changes

### 1. Hardening `WelcomeBonusModal.tsx`
- Ensure `welcome_banner_dismissed` is correctly checked and updated in the database.
- Use a robust `localStorage` flag (e.g., `welcome_bonus_dismissed_${userId}`) in addition to the database field to prevent flicker or re-triggering during hydration/loading states.
- Improve mobile responsiveness by reducing padding and font sizes on small screens.

### 2. Hardening `Onboarding.tsx`
- Currently, it uses `localStorage.getItem(\`onboarding_seen_\${user.id}\`)`.
- Add a session-level safeguard (similar to what was recently added to `WelcomeBonusModal`) to prevent it from re-opening if the user navigates quickly.
- Ensure the modal is responsive on mobile (it currently uses `p-8` and fixed text sizes).

### 3. Verification
- Use Playwright to simulate a first-time login and verify the modals appear.
- Verify that navigating between pages does NOT trigger the modals again.
- Verify mobile layout matches the "responsive" requirement.

## Technical Details

### `WelcomeBonusModal.tsx`
- Update `checkEligibility` to check `localStorage` for the specific user ID.
- Ensure `handleClose` updates `localStorage` immediately.
- Refine the `DialogContent` classes for better mobile fit.

### `Onboarding.tsx`
- Refactor to use a user-specific `localStorage` key consistently.
- Add `sessionStorage` fallback to prevent multi-tab or navigation-induced re-triggers.
- Update UI to use more flexible padding and font sizes.

## Constraints
- Do not remove the "claim" logic, only ensure it doesn't repeat once dismissed or claimed.
- Maintain the Violet-600 theme.
