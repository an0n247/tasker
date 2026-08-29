# Plan - Strictly Enforce One-Time Welcome Bonus

The user reports that the welcome bonus banner persists after refresh and allows multiple credits. Investigation shows the `claim_welcome_bonus` RPC already has a `has_claimed_welcome_bonus` check, but it might be bypassed or incorrectly updated in some migration versions. We will consolidate the RPC and ensure the UI handles the "already claimed" state correctly.

## User Review Required

> [!IMPORTANT]
> This change will strictly block any attempts to claim the welcome bonus more than once. If a user has already claimed it (as marked in their profile), the banner will be permanently hidden for them.

## Technical Details

### 1. Database Consolidation
We will create a final version of the `claim_welcome_bonus` RPC that:
- Uses an explicit `SELECT FOR UPDATE` on the profile to prevent race conditions.
- Strictly checks `has_claimed_welcome_bonus`.
- Uses values from `app_settings` for points if available.
- Updates the `profiles` table **before** inserting transactions.
- Returns a consistent error message if already claimed.

### 2. UI Robustness
- In `src/routes/_authenticated.dashboard.tsx`, we will ensure the `claimWelcomeBonus` mutation properly invalidates and refetches the profile.
- We will add a guard to the banner rendering that double-checks `profile.has_claimed_welcome_bonus` and the mutation success state.

### 3. Verification
- We will run a Playwright test to simulate multiple clicks on the claim button and verify that only one transaction is created and the banner disappears.

## Progress
- [ ] Deploy consolidated `claim_welcome_bonus` RPC.
- [ ] Update Dashboard banner logic.
- [ ] Verify with automated tests.
