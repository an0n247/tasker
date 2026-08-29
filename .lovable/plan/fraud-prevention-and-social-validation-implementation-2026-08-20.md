# Fraud Prevention and Social Validation Implementation

Implement hardened fraud detection to prevent self-referral, multiple accounts from a single user, and social handle duplication.

## User Improvements
- Users will be prevented from using the same social handles (Twitter, Telegram, etc.) across multiple accounts to claim bonuses.
- Real-time validation for social handles on the profile page to ensure they match expected formats.
- Fraud detection for self-referral and multiple accounts from same IP/fingerprint during signup.

## Technical Details

### 1. Database & Security Hardening
- **Fingerprint Tracking**: Add `fingerprint` and `last_ip` columns to `profiles` table to track devices and prevent multi-account abuse.
- **Improved `handle_new_user`**:
    - Add IP/fingerprint checks to flag potential multi-account creation.
    - Prevent self-referral (where user's own details are used as referrer).
- **Hardened `claim_welcome_bonus`**:
    - Enhance existing social handle uniqueness checks to cover all platforms (Twitter, Telegram, Instagram, Facebook).
    - Ensure verification happens BEFORE granting points.

### 2. Frontend Validation
- **Auth Page**:
    - Capture browser fingerprint during signup (if possible via simple means or track IP on backend).
    - Add real-time format validation for social handles on the profile edit screen.
- **Profile Page**:
    - Update the social handle inputs with standard patterns (e.g., Twitter: `^[a-zA-Z0-9_]{1,15}$`).
    - Disable save button if handles don't match criteria.

### 3. Migrations
- SQL migration to:
    - Add `fingerprint` and `last_ip` to `profiles`.
    - Create a `fraud_flags` table for admin review.
    - Update `handle_new_user` trigger with fraud detection logic.
    - Update `claim_welcome_bonus` with cross-handle uniqueness enforcement.

### 4. Admin Panel Enhancement
- Show "Fraud Flags" in the Admin Dashboard for users detected with multiple accounts or suspicious referral chains.
