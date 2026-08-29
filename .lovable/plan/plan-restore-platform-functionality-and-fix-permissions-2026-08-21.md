# Plan - Restore Platform Functionality and Fix Permissions

The recent security hardening migration over-restricted database permissions, causing core features (tasks, rewards, admin panel) to fail. Specifically, revoking `EXECUTE` on the `has_role` function broke all Row-Level Security (RLS) policies that rely on it, and revoking execution on other core functions blocked users from claiming rewards and submitting tasks.

## Proposed Changes

### Database Security & Permissions
- **Restore Function Execution**: Grant `EXECUTE` permission back to `authenticated` users for critical functions:
    - `has_role`: Required for RLS evaluation and admin checks.
    - `claim_welcome_bonus`, `claim_daily_reward`, `submit_task`, `record_video_watch`, `redeem_reward`: Required for users to interact with the platform.
- **Fix Login Lookup**: Grant `EXECUTE` on `lookup_login_email` to `anon` to allow signing in via username.
- **Fix Admin Settings Access**: Add an RLS policy to `app_settings` allowing users with the `admin` role to read all settings, while keeping the restricted view for standard `authenticated` users.
- **Verify RLS Dependencies**: Ensure all tables using `has_role` in their policies have the correct grants to avoid further permission errors.

### Verification Plan
- **Database Audit**: Run SQL queries to verify `GRANT` statements and `pg_policies` reflect the intended state.
- **Feature Testing**: Use Playwright to verify:
    - Admin panel loads correctly (bypassing "Access Denied" for admins).
    - Tasks can be started and submitted.
    - Daily rewards can be claimed.
    - Points balance updates correctly.
- **Auth Testing**: Verify login works using both email and username.
