# Implementation Plan - Enhancements and Spacing Adjustments

This plan addresses layout spacing, referral QR codes, rank implementation, and referrer identity verification.

## User Review Required

> [!IMPORTANT]
> - A new package `qrcode.react` will be installed to generate QR codes locally.
> - The Rank system will be based on referral counts: Novice (0+), Elite (5+), Super Referrer (10+), Pro (20+), and Legend (50+).

## Proposed Changes

### 1. Layout and Spacing
- Update `src/routes/__root.tsx` to increase the top padding (`pt-20` to `pt-24`) to ensure pages don't overlap with the header.
- Audit `src/routes/_authenticated.profile.tsx` and `src/routes/_authenticated.earn.tsx` for consistent top margins.

### 2. Referral QR Code
- Modify `src/components/ReferralStatsDashboard.tsx` to include a QR code for the referral link.
- Users will be able to show their QR code on screen for quick sharing.

### 3. Referral Identity Verification
- Ensure consistency by confirming `referral_code` and `referral_link` usage.
- The `handle_new_user` trigger already uses the code from metadata; no changes needed there, but we will verify the UI displays the same ID.

### 4. Rank System Implementation
- Create a `user_ranks` view to calculate rank based on referral counts.
- Update `src/routes/_authenticated.dashboard.tsx` to display the user's current rank instead of a placeholder.

## Technical Details

### Database Changes
- Create `public.user_ranks` view.
- Create `public.my_referrals_detailed` view for better UI joins.

### Frontend Components
- `ReferralStatsDashboard.tsx`: Import `QRCodeCanvas` from `qrcode.react`.
- `Dashboard.tsx`: Add query for `user_ranks` and display rank badges.

### Spacing Fixes
- `Navigation.tsx`: Ensure the mobile top bar and desktop header have consistent heights and don't overlap content.
- `__root.tsx`: Adjust `main` content padding.

## Verification Plan

### Automated Tests
- Run Playwright tests to check header/content spacing.
- Verify the referral link generated matches the user's referral code.

### Manual Verification
- Check the Dashboard for the new Rank card.
- Verify QR code generates correctly in the Referral tab.
