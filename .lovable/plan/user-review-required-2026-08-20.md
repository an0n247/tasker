---
title: Optimize Admin Panel Performance
description: Improve Admin Panel loading speed by implementing selective data fetching, pagination, and database indexing.
---

## User Review Required

> [!IMPORTANT]
> To make the Admin Panel load faster, I will change how data is fetched from the database. Instead of loading every record at once (which slows down as your user base grows), the panel will load only what is needed for the current view.

- **Selective Loading**: The main Admin Panel will only load the top-level stats initially. Detailed data for Users, Redemptions, and Referrals will only load when you open their respective tabs.
- **Database Optimization**: I will add "indexes" to the database. These are like a book's index, allowing the system to find records (like specific users or redemptions) much faster.

## Proposed Changes

### Database Optimization (Migrations)
- Add indexes to `profiles(created_at)`, `points_transactions(created_at, user_id)`, `redemptions(created_at, user_id)`, and `referrals(created_at)`.
- These indexes will significantly speed up the stats calculation and list filtering.

### Admin Components

#### [src/components/AdminPanel.tsx](src/components/AdminPanel.tsx)
- The main stats query currently fetches *all* transaction and redemption data just to calculate totals. I will optimize this to use database `count` and aggregation functions where possible, or at least scope queries more tightly.

#### [src/components/admin/UsersManager.tsx](src/components/admin/UsersManager.tsx)
- Implement server-side pagination. Currently, it fetches all profiles and filters/paginates them in the browser. This will become very slow with thousands of users.

#### [src/components/admin/RedemptionsManager.tsx](src/components/admin/RedemptionsManager.tsx)
- Implement server-side pagination and filtering.

#### [src/components/admin/ReferralsManager.tsx](src/components/admin/ReferralsManager.tsx)
- Implement server-side pagination and filtering.

## Technical Details

### SQL Migration
```sql
-- Speed up stats and list sorting
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_points_transactions_created_at ON public.points_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_redemptions_created_at ON public.redemptions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_referrals_created_at ON public.referrals(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
```

### Refactoring Strategy
- Use `.range(from, to)` in Supabase queries to fetch only the current page of data.
- Update `useQuery` hooks to include search and filter parameters in the `queryKey`, ensuring fresh data is fetched from the server when filters change.

## Verification Plan

### Automated Tests
- N/A

### Manual Verification
1. Open the Admin Panel and verify the "Total Users" and other stats load quickly.
2. Navigate to the "Users" tab, perform a search, and verify that results update correctly with pagination.
3. Check the "Redemptions" and "Referrals" tabs for similar performance and correctness.
