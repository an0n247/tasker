# Implementation Plan - Fix Data Visibility in Admin and Referral Dashboards

The goal is to ensure the Admin Dashboard and Referral Dashboard show complete and accurate data by addressing missing database permissions (RLS policies) and correcting data fetching logic.

## User Review Required

> [!IMPORTANT]
> The admin needs full visibility into all users to manage the platform effectively. I will enable policies that allow users with the 'admin' role to see all profile data.

## Proposed Changes

### Database Security (Supabase)

#### 1. Add Admin Visibility Policies
Add RLS policies to allow administrators to see all records across core tables. Currently, admins can only see their own profile.
- Add `SELECT` policy on `public.profiles` for `authenticated` users where `has_role(auth.uid(), 'admin')` is true.
- Add `SELECT` policy on `public.referrals` for `authenticated` users where `has_role(auth.uid(), 'admin')` is true.
- Add `SELECT` policy on `public.points_transactions` for `authenticated` users where `has_role(auth.uid(), 'admin')` is true.

#### 2. Fix Analytics Permissions
Ensure the `analytics_events` and other tracking tables are readable by admins for the dashboard stats.

### Frontend Logic Fixes

#### 1. Fix Referral Tracking Logic (`src/routes/_authenticated.refer.tsx`)
- The current logic incorrectly queries `profiles` using a non-existent column `referral_code_used`.
- Update the query to join with the `referrals` table or use the `referred_by` column in the `profiles` table to correctly identify who was referred by the current user.

#### 2. Update Admin User Manager (`src/components/admin/UsersManager.tsx`)
- Ensure the query fetches all profiles now that the RLS policy will permit it.

#### 3. Verify Admin Dashboard Stats (`src/components/AdminPanel.tsx`)
- Ensure "Total Users" and "Total Points" counts use admin-privileged queries to reflect the entire platform, not just the admin's personal data.

## Verification Plan

### Manual Verification
- Log in as the admin user (`rolalekanhq@gmail.com`).
- Navigate to the **Admin Panel**.
- Verify the **Users** tab shows all 4 existing users (Ridwan Adeyemo, Olalekan Ridwan, Adeniyi Lekan, and Test User).
- Verify the **Analytics** tab shows correct platform-wide totals.
- Log in as a user who has referrals (e.g., `lifelineng`).
- Navigate to the **Refer** page.
- Verify that the "Total Referrals" count and the list of referred users are accurate based on the `referrals` table.

### Automated Verification
- Use `lovable supabase query` to verify that the new RLS policies exist.
- Run a browser script to count rows in the Admin User table and compare against the total profile count.
