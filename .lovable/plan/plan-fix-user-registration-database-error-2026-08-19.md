# Plan: Fix User Registration Database Error

Investigate and fix the recurring "database error saving new user" during signup.

## Technical Details

The issue likely stems from the `handle_new_user` trigger function or related triggers (e.g., `reward_referrer_on_signup`) on the `public.profiles` table. Multiple migrations have redefined these functions, potentially introducing conflicts, missing columns, or permission issues.

### Proposed Changes

1.  **Harden `handle_new_user` Trigger**:
    *   Ensure the `handle_new_user` function is robust against missing metadata.
    *   Validate that all columns being inserted into `public.profiles` exist (`id`, `username`, `full_name`, `avatar_url`, `referral_code`, `referred_by`, `email`, etc.).
    *   Ensure the `referred_by` lookup correctly handles the `referral_code_used` or `referral_code` from metadata.
    *   Use `ON CONFLICT (id) DO UPDATE` to gracefully handle retries or edge cases where an auth user exists but the profile creation failed previously.

2.  **Harden `reward_referrer_on_signup` Trigger**:
    *   Verify the trigger logic for awarding points to both referrer (75) and referee (50).
    *   Ensure it correctly handles cases where a `notifications` table might or might not exist.
    *   Check for recursive trigger issues or lock contention.

3.  **Database Permissions**:
    *   Ensure `GRANT EXECUTE` is explicitly set for `service_role` and `postgres` on all trigger functions.
    *   Verify `GRANT INSERT, SELECT, UPDATE` on `public.profiles`, `public.referrals`, and `public.points_transactions`.

4.  **Verification**:
    *   Run a test signup flow via the browser to verify the fix.
    *   Check `supabase.auth.signUp` response and database logs.

### Steps

1.  Read the current state of `public.profiles` schema to confirm all columns.
2.  Apply a consolidated migration to fix the triggers.
3.  Test registration with and without a referral code.
