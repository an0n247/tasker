# Plan - Fix Welcome Bonus Settings (Create app_settings table)

The admin panel is unable to manage Welcome Bonus settings because the `app_settings` table was defined in a migration file but never successfully created in the database. I will create the table, set up appropriate RLS policies, grant necessary permissions, and seed it with initial values.

## Proposed Changes

### Database

#### Create `app_settings` Table
Create a new table `public.app_settings` to store global application configurations like welcome bonus amounts and eligibility requirements.

- **Columns**:
  - `id`: UUID (Primary Key)
  - `key`: TEXT (Unique, e.g., 'welcome_bonus_enabled')
  - `value`: JSONB (Stores the setting value)
  - `description`: TEXT (Human-readable description)
  - `updated_at`: TIMESTAMPTZ

#### Security & Permissions
- Enable Row-Level Security (RLS).
- Grant `SELECT` access to all `authenticated` users (so the app can read settings).
- Grant `ALL` (Insert, Update, Delete, Select) to `authenticated` users who have the `admin` role via the `has_role` function.
- Grant `ALL` to the `service_role`.

#### Seed Data
Insert initial settings for the Welcome Bonus:
- `welcome_bonus_enabled`: `true`
- `welcome_bonus_amount_referee`: `50`
- `welcome_bonus_amount_referrer`: `75`
- `welcome_bonus_required_socials`: `["twitter", "telegram"]`

## Verification Plan

### Automated Tests
- Run a SQL query to verify the table `app_settings` exists and contains 4 rows.
- Verify that the `has_role` function exists (required for the RLS policy).

### Manual Verification
- Navigate to the Admin Panel.
- Go to the Settings / Welcome Bonus section.
- Attempt to change a value (e.g., the bonus amount) and save.
- Verify that no "table not found" error appears and the change persists after refreshing.
