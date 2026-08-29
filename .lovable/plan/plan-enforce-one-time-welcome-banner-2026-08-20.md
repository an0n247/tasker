# Plan: Enforce One-Time Welcome Banner

The user wants the welcome bonus banner to show only once per account. Currently, it uses `sessionStorage` to track dismissal, which resets when the browser is closed or the page is reloaded in a new session. I will move this tracking to the user's profile in the database.

## User Review Required

> [!IMPORTANT]
> This change will permanently mark the welcome bonus as "dismissed" for an account once a user closes the modal. They won't see it again on other devices or after clearing browser storage.

## Proposed Changes

### 1. Database Schema
- Add a `welcome_banner_dismissed` boolean column to the `profiles` table to track if the user has closed the modal without claiming.

### 2. Backend Logic (Supabase)
- Update the `profiles` table with the new column.
- Update the `claim_welcome_bonus` function (if necessary) to also set this flag, though its primary check is already `has_claimed_welcome_bonus`.

### 3. Frontend Implementation
- **src/components/WelcomeBonusModal.tsx**:
    - Update `checkEligibility` to check `profile.welcome_banner_dismissed` instead of `sessionStorage`.
    - Update `handleClose` to call a Supabase update to set `welcome_banner_dismissed = true` in the database instead of setting `sessionStorage`.

## Technical Details

### Migration
```sql
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS welcome_banner_dismissed BOOLEAN DEFAULT FALSE;
```

### Frontend Logic
- The modal currently checks: `profileData.referred_by && !profileData.has_claimed_welcome_bonus`.
- I will add: `&& !profileData.welcome_banner_dismissed`.
- When the user clicks "Claim later" or closes the modal, I'll update the profile:
  ```typescript
  await supabase.from('profiles').update({ welcome_banner_dismissed: true }).eq('id', user.id);
  ```
