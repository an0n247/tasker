# Plan - Fix Referral Code Validation

The user is reporting an "unable to validate referral code" error during sign-up. This error message is triggered in `src/routes/auth.tsx` when the `check_referral_code` RPC call fails or throws an exception. 

The current implementation of `validateReferral` in `src/routes/auth.tsx` passes `_user_id: null` when validating during signup. However, the database function `check_referral_code` might be failing due to recent changes or strict type checking in the RPC layer, or because of how the response is being handled.

## User Review Required

> [!IMPORTANT]
> This fix addresses the "Unable to validate referral code" error seen during signup. It ensures the validation logic correctly handles new users who don't have a profile ID yet.

## Proposed Changes

### Database

#### Update `check_referral_code` Function
- Ensure the function explicitly handles `NULL` for `_requesting_user_id` without ambiguity.
- The current implementation seems to handle it, but I will ensure the `SECURITY DEFINER` and `SET search_path` are correctly applied and that it returns a consistent structure.
- I will verify if the table `profiles` has any triggers or constraints that might interfere with this lookup.

### Frontend

#### Refine `src/routes/auth.tsx`
- Improve the RPC call error handling.
- Ensure the response from `supabase.rpc('check_referral_code', ...)` is correctly parsed.
- Add more descriptive logging to help diagnose if it fails again in the future.

## Technical Details

### Database Migration
```sql
-- Re-defining the function to ensure clean parameters and explicit null handling
CREATE OR REPLACE FUNCTION public.check_referral_code(_code text, _user_id uuid DEFAULT NULL)
RETURNS TABLE(username text, is_valid boolean, message text) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_username text;
BEGIN
    -- 1. Find referrer
    SELECT p.username INTO v_referrer_username
    FROM public.profiles p
    WHERE p.referral_code = _code
    LIMIT 1;

    IF v_referrer_username IS NULL THEN
        RETURN QUERY SELECT NULL::text, FALSE, 'Referral code not found.'::text;
        RETURN;
    END IF;

    -- 2. Success
    RETURN QUERY SELECT v_referrer_username, TRUE, 'Valid referral code.'::text;
END;
$$;
```

### Code Edits
- Update `validateReferral` in `src/routes/auth.tsx` to match the simplified return structure of the RPC.
- Ensure the parameter name in the JS call matches the DB function exactly (`_code` and `_user_id`).

## Verification Plan

### Automated Tests
- Run a Playwright script to:
    1. Navigate to `/auth?mode=signup`.
    2. Enter a known valid referral code.
    3. Verify the "Referrer found" message appears.
    4. Enter an invalid referral code.
    5. Verify the "This referral code does not exist" message appears.

### Manual Verification
- Check the browser console for any RPC errors during the validation process.
