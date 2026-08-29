# Plan: Fix Referral Validation, Profile Display, and Auth Layout

The user is reporting issues with referral code validation during sign-up, missing user details (name/username) in the profile, and layout constraints on the auth page.

## User Requirements
- Fix "unable to validate referral code" error during sign-up.
- Ensure full name and username are correctly displayed in the profile page after registration.
- Allow the sign-up/login page to scroll freely instead of being locked in a fixed-height container.

## Proposed Changes

### 1. Database & Security
- **Fix Referral Validation**: Ensure the `check_referral_code` RPC is executable by the `anon` role. The previous hardening restricted it to `authenticated` only, but validation happens *before* sign-up.
- **Verify Trigger**: Ensure the `handle_new_user` trigger correctly propagates `full_name` and `username` from auth metadata to the `profiles` table.

### 2. Authentication UI (`src/routes/auth.tsx`)
- **Fix Layout**: Remove `md:h-screen` and `overflow-hidden` from the outer containers to allow natural scrolling on all devices.
- **Fix Inner Container**: Adjust the `Card` component's `max-h-[85dvh]` and `overflow-hidden` constraints to prevent clipping on smaller screens or during long forms.

### 3. Profile Page (`src/routes/_authenticated.profile.tsx`)
- **Display Details**: Verify and fix the data fetching logic to ensure `full_name` and `username` are always populated from the database.
- **Navigation Update**: Ensure the global navigation header correctly displays the username from the profile state.

## Technical Details
- **SQL Migration**: Grant `EXECUTE` on `check_referral_code(text, uuid)` to `anon`.
- **CSS/Tailwind**: Change `min-h-[100dvh] md:h-screen` to `min-h-screen` and remove `overflow-hidden` on `src/routes/auth.tsx`.
- **Profile Logic**: Ensure `profiles` table RLS allows users to read their own `full_name` and `username`.

## Verification Plan
- **Automated Tests**: Run a Playwright script to verify:
    1. Navigation to `/auth?mode=signup`.
    2. Inputting a valid referral code triggers a success message (mocking the RPC response if needed or using a test referral).
    3. Checking for scrollbars when the content exceeds viewport height.
- **Manual Verification**: Check the profile page after a test registration to confirm names are visible.
