# Implementation: Reward Redemption and Referral System

## 1. Reward Redemption Flow
- **Confirmation Modal**: Added a modern `Dialog` in `src/routes/_authenticated.redeem.tsx` that appears when a user clicks "Redeem Now".
- **Point Verification**: The modal shows the current balance, the cost of the reward, and the projected balance after redemption.
- **Backend Logic**:
    - Deducts points from the user's balance via `points_transactions`.
    - Creates a record in the `redemptions` table with a 'pending' status.
    - Provides real-time feedback using `sonner` toasts and invalidates queries to update the UI immediately.

## 2. Referral Code Redemption and Crediting
- **Signup Integration**: Updated `src/routes/auth.tsx` to include `referral_code_used` in the user's metadata during signup.
- **Database Hardening**:
    - Added `referral_code_used` column to the `profiles` table to track which code was used at signup.
    - Implemented `reward_referrer_on_signup()` trigger function in Supabase.
    - When a new profile is created, the system checks if a valid referral code (username) was used.
    - If valid, the referrer is automatically credited with **50 points**.
    - An automatic notification is sent to the referrer announcing their reward.
- **UI Tracking**: Updated `src/routes/_authenticated.refer.tsx` to track referrals based on the username code used, ensuring users can see their successful invites.

## Technical Details
- **Tables Modified**: `profiles` (added `referral_code_used`).
- **Triggers Added**: `on_profile_referral_reward` on `public.profiles`.
- **Functions Added**: `public.reward_referrer_on_signup()`.
- **Components Updated**: `RedeemPage`, `AuthPage`, `ReferralPage`.
