# Plan: Admin-configurable Welcome Bonus

The user wants to transition from hardcoded welcome bonus logic (amount and eligibility) to an admin-configurable system stored in the database.

## Proposed Changes

### Database Schema
- Create a `public.app_settings` table to store platform-wide configurations.
- Schema: `id (uuid)`, `key (text, unique)`, `value (jsonb)`, `description (text)`, `updated_at (timestamptz)`.
- Insert initial settings for:
    - `welcome_bonus_enabled` (boolean)
    - `welcome_bonus_amount_referee` (integer)
    - `welcome_bonus_amount_referrer` (integer)
    - `welcome_bonus_required_socials` (text array: e.g., `['twitter', 'telegram']`)

### Backend (PostgreSQL Functions)
- Update the `public.claim_welcome_bonus` function to read values from `public.app_settings` instead of using hardcoded variables (`v_referral_points_referrer`, `v_referral_points_referee`).
- Use these settings to determine eligibility (enabled status and required social handles).

### Admin Interface
- Create a new component `src/components/admin/PlatformSettings.tsx` to allow admins to edit these values.
- Integrate this component as a new tab in the `AdminPanel`.

### Frontend Logic
- Update `WelcomeBonusModal.tsx` to fetch the bonus amount and status from `app_settings` (via profile metadata or a new RPC/query) to show accurate information to the user.

## Technical Details
- **RLS**: `app_settings` should be readable by `authenticated` users but only writable by `admin` (via the `has_role` function).
- **Graceful Fallbacks**: The SQL function will use COALESCE with hardcoded defaults if settings are missing.

## Verification Plan
- As an admin, change the welcome bonus amount to `100`.
- Sign up as a new user via referral and verify the modal shows `100` points.
- Verify claiming the bonus credits the correct amount defined in the settings.
- Disable the welcome bonus in settings and verify the modal no longer appears for new users.
