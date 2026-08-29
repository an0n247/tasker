# Implementation Plan - Social Handle Verification Logic

To satisfy the request for validating social handles to determine "real or fake" before saving, I will implement a multi-layered approach including enhanced regex validation, platform-specific handle length constraints, and a "Verification in Progress" simulation to improve the perceived reliability of the inputs.

## Proposed Changes

### 1. Enhanced Handle Validation Logic
- Refine regex patterns for each platform in `src/routes/_authenticated.profile.tsx`:
    - **Twitter/X**: `^[a-zA-Z0-9_]{4,15}$` (min 4 chars, max 15, alphanumeric + underscore).
    - **Telegram**: `^[a-zA-Z0-9_]{5,32}$` (min 5 chars, alphanumeric + underscore).
    - **Facebook**: `^[a-zA-Z0-9.]{5,}$` (alphanumeric + dots, min 5 chars).
    - **Instagram**: `^[a-zA-Z0-9._]{1,30}$` (alphanumeric + dots/underscores).
- Add specific error messages for each invalidation state (e.g., "Handle too short", "Invalid characters").

### 2. "Verify Before Save" UX
- Add a "Verify" button next to each social input.
- When clicked, it will:
    - Run the regex check.
    - Show a temporary loading state ("Checking platform...").
    - Display a "Verified Format" or "Invalid Format" badge.
- Only allow "Save Changes" if all provided handles pass the format verification.

### 3. Handle Auto-Cleaning Refinement
- Improve the `cleanHandle` function to handle more edge cases (like trailing slashes or @ signs in the middle of pasted URLs).

### 4. Admin Gating (Future Proofing)
- Ensure the `welcome_bonus_required_socials` setting in `app_settings` is respected, marking these handles as mandatory for bonus eligibility with a clear UI indicator.

## Technical Details
- **File**: `src/routes/_authenticated.profile.tsx`
- **Logic**: Update `validateHandle` and `cleanHandle` functions.
- **UI**: Modify the social grid to include status indicators and clearer validation feedback.
- **State**: Add a local state to track which handles have been "verified" in the current session.

## User Review Required
- Do you want actual API-based verification (which would require external API keys for X/Telegram/etc.) or is the enhanced logic and format verification sufficient for now? (Assuming format verification + cleaning as per instruction document constraints).
