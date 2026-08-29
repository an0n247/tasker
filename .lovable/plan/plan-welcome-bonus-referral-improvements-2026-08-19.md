# Plan: Welcome Bonus & Referral Improvements

Implement a one-time welcome bonus claim popup for new users and improve the referral code validation during sign-up.

## User Review Required

> [!IMPORTANT]
> The welcome bonus (50 points) is currently awarded automatically in the database via the `reward_referrer_on_signup` trigger when a user signs up with a referral code. This plan adds a UI popup for the user to "claim" it (confirming they see the reward), while keeping the underlying balance secure.

## Proposed Changes

### Database Schema & Logic
- Add `has_claimed_welcome_bonus` boolean column to `public.profiles` (defaults to `false`).
- Create a `check_referral_code` RPC function to validate codes during sign-up.
- Create a `claim_welcome_bonus` RPC function that marks the bonus as claimed.

### Frontend Enhancements

#### Sign-up Improvements (`src/routes/auth.tsx`)
- Add real-time validation to the Referral Code input.
- Show a status message ("Referrer found: [Username]" or "Invalid code") immediately when the user finishes typing.

#### Welcome Bonus Popup (`src/components/WelcomeBonusModal.tsx`)
- Create a branded modal for new users who joined via referral.
- Includes a "Claim Your 50 Points" button with a confetti effect.

#### Dashboard Integration (`src/routes/_authenticated.dashboard.tsx`)
- Mount the `WelcomeBonusModal` to show on first login.

## Technical Details (SQL)
```sql
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS has_claimed_welcome_bonus BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION public.check_referral_code(_code TEXT)
RETURNS TABLE (username TEXT, exists BOOLEAN) 
LANGUAGE plpgsql SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    RETURN QUERY SELECT p.username, TRUE FROM public.profiles p WHERE p.referral_code = _code;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT) TO authenticated, anon;
```
