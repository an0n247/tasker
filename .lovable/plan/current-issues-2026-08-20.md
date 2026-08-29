---
name: RLS Fix for Redemptions and Point Adjustments
description: Fix "new role violates row-level security policy" error by using RPCs and granting permissions.
type: feature
---

The user is encountering RLS errors when redeeming rewards and when admins try to adjust points manually. 

### Current Issues
1. **Redemption**: While a `redeem_reward` RPC exists, the error "new role violates row-level security policy" suggests the user might be attempting a direct insert or the RPC is calling a restricted action without proper grants. However, looking at the code, `redeem_reward` is `SECURITY DEFINER` and should work if the RLS on the tables it touches allows the *owner* (service_role/admin) to perform the actions.
2. **Point Adjustments**: Admins are attempting to insert directly into `points_transactions` from the frontend. Direct inserts into transaction tables are often restricted to prevent balance manipulation.

### Proposed Solutions
1. **Redemption**: 
   - Ensure `redeem_reward` is being called correctly from the frontend (it is).
   - Ensure the `redemptions` and `points_transactions` tables have `GRANT`s for the `service_role` (which `SECURITY DEFINER` uses).
   - Verify if any RLS policy on `redemptions` is blocking the insert even for the RPC.
2. **Point Adjustments**:
   - Create a `SECURITY DEFINER` RPC for admins to adjust points instead of direct insertion. This ensures the action is audited and bypasses RLS safely while maintaining integrity.
   - Update `ReferralsManager.tsx` to use this new RPC.

### Technical Steps

#### 1. Database Migration
- Create `adjust_user_points` RPC for admins.
- Ensure proper `GRANT` statements for `redemptions` and `points_transactions`.
- Revoke public/authenticated access to `adjust_user_points` and grant only to authenticated users (then check role inside).

#### 2. Frontend Changes
- Update `src/components/admin/ReferralsManager.tsx` to use the new `adjust_user_points` RPC instead of direct `supabase.from("points_transactions").insert()`.
- Update other admin components (RedemptionsManager, etc.) if they perform direct inserts into protected tables.

#### 3. Security Review
- Verify that `SECURITY DEFINER` functions have `SET search_path = public` (they mostly do).
- Ensure `has_role` is used correctly to restrict admin-only RPCs.
