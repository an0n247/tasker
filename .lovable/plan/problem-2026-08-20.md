---
name: Fix Welcome Bonus Modal behavior and responsiveness
description: Address issues where the welcome bonus modal repeats every click and is too large on mobile.
type: feature
---

## Problem
- The welcome bonus modal is showing too frequently ("on every click").
- The modal is not responsive enough and appears "too big" on mobile devices.

## Solution
### Logic Fix
- Enhance `WelcomeBonusModal.tsx` to strictly check for the `welcome_banner_dismissed` flag in the user's profile.
- Ensure `sessionStorage` is used correctly as a backup to prevent re-triggering within the same session after it's been handled.
- Verify that `handleClose` correctly updates the database and invalidates the profile query.

### UI Fix
- Adjust `DialogContent` padding and max-height for mobile.
- Scale down decorative elements and icons on smaller screens.
- Ensure the modal content is scrollable if it exceeds the viewport height on small devices.

## Technical Details
- **File**: `src/components/WelcomeBonusModal.tsx`
- **Changes**:
    - Update `checkEligibility` to prioritize `profileData.welcome_banner_dismissed` check.
    - Refine `DialogContent` className with `max-h-[90dvh] overflow-y-auto`.
    - Adjust padding and spacing in the modal body for `sm` and `xs` breakpoints.
    - Reduce image and icon sizes for mobile viewports.
