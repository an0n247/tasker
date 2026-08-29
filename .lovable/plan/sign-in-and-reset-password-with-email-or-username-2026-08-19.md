# Sign in and reset password with email or username

## Problem confirmed

The login form already accepts "Email or Username" and looks the username up through the `get_user_email_by_username` database function. However, that function's execute permission is currently granted only to `postgres` and `service_role` — signed-out visitors cannot call it, so username login fails today.

Password reset only accepts an email address; usernames are rejected by the form.

## What will change

1. **Make username lookup work for signed-out visitors**
   - New migration adding a hardened lookup function usable before sign-in: takes a username, returns the matching account email, no other data.
   - Grant execute to the anonymous role only for this single function (it exposes nothing beyond what a reset flow already reveals). Case-insensitive and trimmed matching so `Ola` and `ola ` both work.

2. **Login**
   - Keep the existing "Email or Username" field; route non-email input through the lookup.
   - Friendly, non-enumerating error: "Incorrect username/email or password" instead of "Could not find account with that username."

3. **Password reset**
   - Relabel the field to "Email or Username" and drop the email-only validation.
   - If the input has no `@`, resolve it to an email via the lookup, then send the reset link to that address.
   - Always show the same neutral success message ("If an account exists, a reset link has been sent") so the form cannot be used to test which usernames exist.
   - Keep prefilling the reset field from whatever was typed on the login form, now for usernames too.

## Technical notes

- Files touched: one new SQL migration, and `src/routes/auth.tsx` (`handleEmailLogin`, `handlePasswordReset`, reset form markup).
- The lookup function stays `SECURITY DEFINER` with `search_path = public` and returns only the email string; no change to any table policy or grant.
- Reset redirect target stays `window.location.origin + "/auth"`.
