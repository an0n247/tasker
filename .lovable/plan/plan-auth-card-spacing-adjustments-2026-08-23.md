# Plan - Auth Card Spacing Adjustments

Adjust the spacing in the authentication card to improve visual balance, specifically between the Google login button, the "or email" divider, and the login/signup tabs, as well as between the form fields and the action button.

## User Review Required

> [!IMPORTANT]
> I am increasing the spacing that was previously reduced to ensure the elements have enough "breathing room" as requested.

- Does the proposed spacing (approx. 12-16px between groups) sound correct?

## Proposed Changes

### Authentication Page

#### [src/routes/auth.tsx](src/routes/auth.tsx)

- Increase vertical margin between "Continue with Google" button and the "or email" divider.
- Increase vertical margin between the "or email" divider and the Tabs/Form sections.
- Add more spacing between the last input field (or "Forgot password" link) and the primary action button ("Sign in" / "Create account").
- Slightly increase the gap in `space-y-3` for the forms to `space-y-4` where appropriate to avoid elements being too close.

## Verification Plan

### Automated Tests
- Run Playwright to capture a screenshot of the auth page on mobile and desktop to verify the new spacing.
- `mkdir -p /tmp/browser/auth-spacing && python3 /tmp/browser/auth-spacing/check_spacing.py`

### Manual Verification
- View the Auth page in the preview.
- Toggle between Sign In and Sign Up tabs to ensure consistent spacing.
- Check the "Forgot Password" view for similar spacing consistency.
