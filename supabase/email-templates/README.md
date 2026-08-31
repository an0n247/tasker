# Noble Gain — Supabase Auth Email Templates

This folder contains a unified, brand-consistent email design system for all Supabase Auth emails for **Noble Gain** (`noblegain.name.ng`).

## Quick Setup in Supabase Dashboard

Go to your Supabase project email templates:
👉 **[https://supabase.com/dashboard/project/pvqlludcqgfnuivllzch/auth/templates](https://supabase.com/dashboard/project/pvqlludcqgfnuivllzch/auth/templates)**

---

### 1. Confirm signup (Registration OTP)
- **Template File**: [`1-confirm-signup.html`](./1-confirm-signup.html)
- **Subject**: `{{ .Token }} is your Noble Gain verification code`
- **Purpose**: Sends the 6-digit OTP when a user registers on `/auth`.

---

### 2. Reset Password (Recovery Code & Link)
- **Template File**: [`2-reset-password.html`](./2-reset-password.html)
- **Subject**: `Reset your Noble Gain password`
- **Purpose**: Sends a secure password reset button and backup recovery code.

---

### 3. Magic Link (Direct Sign-In)
- **Template File**: [`3-magic-link.html`](./3-magic-link.html)
- **Subject**: `Your Noble Gain sign-in link`
- **Purpose**: Passwordless 1-click login and fallback one-time login code.

---

### 4. Change Email Address
- **Template File**: [`4-change-email.html`](./4-change-email.html)
- **Subject**: `Confirm your new Noble Gain email address`
- **Purpose**: Confirmation link and code when a user updates their account email.

---

### 5. Invite User
- **Template File**: [`5-invite-user.html`](./5-invite-user.html)
- **Subject**: `You've been invited to join Noble Gain`
- **Purpose**: Admin-issued invitation to onboard new team members or users.
