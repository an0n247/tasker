---
name: Fix Admin Access and Data Visibility
description: Restore database grants for admin and content tables to fix "not available" and missing admin panel errors.
type: feature
---

## Problem
The user is experiencing "not available" messages for tasks/rewards and the Admin Panel is not showing. Investigation reveals that while the data exists in the database, the `GRANT` permissions on several public schema tables (tasks, rewards, user_roles, etc.) are missing, preventing the application from reading them.

## Technical Details
- **Affected Tables**: `tasks`, `rewards`, `user_roles`, `profiles`, `points_transactions`, `redemptions`, `notifications`, `user_streaks`, `task_submissions`.
- **Root Cause**: Missing `GRANT` statements in the public schema for the `authenticated` and `anon` roles. RLS is enabled, but standard Supabase Data API access requires explicit grants.
- **Verification**: Database queries confirmed data exists but `information_schema` shows no privileges for standard roles.

## Proposed Changes

### Database Migration
Create a new migration to apply broad and specific grants:
1. **Content Tables**: `GRANT SELECT ON public.tasks, public.rewards TO authenticated, anon`.
2. **Admin/User Tables**: `GRANT SELECT ON public.user_roles, public.profiles, public.points_transactions, public.redemptions, public.notifications, public.user_streaks, public.task_submissions TO authenticated`.
3. **Full Admin Access**: `GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role`.
4. **Admin Role Grants**: Explicitly ensure `authenticated` can select from `user_roles` to allow the `has_role` check in the admin route to pass.

### UI/Route Fixes
1. **Admin Route**: Verify `src/routes/_authenticated.admin.tsx` correctly handles the session and `has_role` RPC.
2. **Data Fetching**: Ensure components like `EarnPage` and `AdminPanel` handle empty states gracefully while the data is loading or if it's truly missing.

## Validation Plan
1. **Manual Check**: Verify the admin user (`rolalekanhq@gmail.com`) can see the "Administration" heading and `AdminPanel` content.
2. **Data Check**: Confirm tasks appear on the `/earn` page and rewards on the `/redeem` page.
3. **Logs**: Check browser console for 403 Forbidden or 401 Unauthorized errors from PostgREST.
