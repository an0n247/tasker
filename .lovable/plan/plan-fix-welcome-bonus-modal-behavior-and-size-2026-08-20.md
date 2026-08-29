# Plan: Fix Welcome Bonus Modal behavior and size

The user wants to ensure the "Welcome to EarnPal" popup (WelcomeBonusModal) only shows once and is not too large on mobile devices.

## Proposed Changes

### `src/components/WelcomeBonusModal.tsx`
- **Enforce one-time display**:
    - The `checkEligibility` function already checks `!profileData.has_claimed_welcome_bonus` and `!profileData.welcome_banner_dismissed`.
    - However, it might be showing repeatedly if the dismiss state isn't correctly handled or if the check runs too frequently.
    - I will add a `sessionStorage` guard as an extra layer to prevent it from popping up multiple times during the same session if the DB update is slow.
- **Mobile Size Improvements**:
    - Update `DialogContent` to use more responsive classes.
    - Specifically, adjust padding and max-width on smaller screens.
    - Reduce the height of the top decorative section on mobile.
    - Adjust font sizes and button height for mobile screens to ensure it fits better within the viewport.

## Technical Details
- Use `max-w-[90vw]` or `max-w-md` with proper mobile overrides.
- Use `h-24 md:h-32` for the header image container.
- Use `p-6 md:p-8` for padding adjustments.

## Verification Plan
- Login as a referred user and verify the modal appears.
- Dismiss the modal and verify it does not reappear on refresh.
- Check the modal on mobile viewport sizes (e.g., 375x667) to ensure it fits comfortably.
