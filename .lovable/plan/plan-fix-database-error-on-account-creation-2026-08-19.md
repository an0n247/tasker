# Plan - Fix Database Error on Account Creation

The user is encountering a "database error saving new user" during account creation. Based on the analysis of the `handle_new_user` trigger function and the `profiles` table schema:

1.  **Analysis**:
    - The `handle_new_user` function uses `gen_random_bytes(6)` which requires the `pgcrypto` extension. While `pgcrypto` is installed, there might be a permission issue or a failure in the `encode(..., 'hex')` step if not handled correctly.
    - More importantly, the `handle_new_user` function was previously modified to have `REVOKE EXECUTE ... FROM PUBLIC` and `GRANT EXECUTE ... TO service_role`. In Supabase, triggers on `auth.users` run as the `postgres` or `supabase_admin` user, but they must be executable by the process performing the insert.
    - If the trigger function fails, the entire user creation in `auth.users` fails, resulting in a database error during signup.
    - The `referral_code` column is unique, and `encode(gen_random_bytes(6), 'hex')` might theoretically collide (though unlikely with 12 hex chars), but the immediate error is likely related to the function's search path or execution permissions recently tightened.

2.  **Proposed Fix**:
    - Ensure the `handle_new_user` function has the correct `search_path` (already done in a previous turn but I will verify/re-apply to be safe).
    - Ensure the function is executable by the necessary roles.
    - Add error handling/logging within the trigger or simplify the referral code generation if it's the culprit.

## User Review Required

> [!IMPORTANT]
> I will simplify the referral code generation and ensure the trigger function has the correct permissions to prevent the "database error" during signup.

## Technical Details

- **Database**:
    - Update `public.handle_new_user` function to use a more robust way to generate the `referral_code` if `gen_random_bytes` is failing.
    - Ensure `GRANT EXECUTE` is correctly set for the `postgres` role (which usually handles triggers).
    - Double-check that the `profiles` table allows inserts from the trigger (which usually bypasses RLS if `SECURITY DEFINER` is used, which it is).
