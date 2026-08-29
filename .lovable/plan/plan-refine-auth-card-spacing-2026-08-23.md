# Plan - Refine Auth Card Spacing

Further adjust the vertical spacing between the Google login button, the "or email" divider, and the login/signup tabs to achieve a more balanced and professional layout.

## Proposed Changes

### Authentication Page

#### [src/routes/auth.tsx](src/routes/auth.tsx)

- Update spacing around the Google button and the divider to ensure even "breathing room".
- Current `mt-4` on Google button and `my-3` on divider might need slight adjustments to feel "properly separated" as per user feedback.
- Ensure the gap between the divider and the `Tabs` component is equal to the gap between the Google button and the divider.

## Verification Plan

### Automated Tests
- Run Playwright to capture a screenshot of the auth page on mobile and desktop.
- `mkdir -p /tmp/browser/auth-spacing-v2 && python3 /tmp/browser/auth-spacing-v2/check_spacing.py`

### Manual Verification
- View the Auth page in the preview.
- Confirm the vertical rhythm feels consistent (e.g., gap above divider == gap below divider).
