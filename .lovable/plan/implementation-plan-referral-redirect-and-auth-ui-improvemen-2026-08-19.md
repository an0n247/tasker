# Implementation Plan: Referral Redirect and Auth UI Improvements

The goal is to streamline the referral process by automatically redirecting users with a referral link to the sign-up page and fixing the UI headings on the authentication page.

## 1. Referral Link Logic
- **Landing Page Redirect**: Update `src/routes/index.tsx` to detect the `ref` query parameter. If present, it will automatically redirect the user to `/auth?mode=signup&ref=USERNAME`.
- **Auth Page Initial State**: Update `src/routes/auth.tsx` to read a `mode` parameter. If `mode=signup`, the "Sign Up" tab will be active by default.
- **Referral Code Application**: Ensure the `ref` parameter from the URL is pre-filled into the referral code field on the sign-up form.

## 2. Auth UI Heading Fix
- **Dynamic Headings**: Modify the `CardTitle` and `CardDescription` in `src/routes/auth.tsx` to update based on whether the user is viewing the "Login" or "Sign Up" tab.
    - **Login**: "Welcome back" / "Access your dashboard to start earning rewards"
    - **Sign Up**: "Create Account" / "Join the Earn Pal community and start earning today"
- **Tab Sync**: Ensure the headings update immediately when the user switches tabs.

## Technical Details
- **Files to Modify**:
    - `src/routes/index.tsx`: Add `validateSearch` and `beforeLoad` logic for the referral redirect.
    - `src/routes/auth.tsx`: Update `validateSearch`, `AuthPage` state initialization, and conditional rendering for headings.
- **Search Parameters**:
    - `/`: Added `ref` (string, optional).
    - `/auth`: Added `mode` (enum: 'login' | 'signup', optional) and `ref` (string, optional).
