# Plan: Capitalize Username in Greetings and Profile

The goal is to ensure the username's first letter is capitalized whenever it's shown in greetings (like "Welcome back, [Username]") or in profile titles/headers.

## User Review Required
> [!IMPORTANT]
> This will only affect how the username is **displayed** in the UI. The actual value in the database will remain unchanged.

## Proposed Changes

### 1. Navigation Component
- Locate greeting in desktop top bar (around line 324) and sidebar (around line 181).
- Locate username in mobile dropdown (around line 246) and desktop dropdown (around line 352).
- Apply a helper function or inline capitalization logic: `(profile.username.charAt(0).toUpperCase() + profile.username.slice(1))`.

### 2. Dashboard Route
- Locate greeting in the main header (line 105).
- Apply capitalization logic to `profile.username`.

### 3. Profile Route
- Locate username display in the profile card (line 191).
- Apply capitalization logic.

## Technical Details
- I will create a small utility function or just use inline logic if it's simpler for these specific spots.
- The change is purely visual and uses standard JavaScript string manipulation.

## Verification Plan
### Automated Tests
- Run Playwright to check the dashboard and profile pages.
- Verify that the text "Welcome back, [username]" shows the username with a capital letter.

### Manual Verification
- Check the desktop sidebar.
- Check the mobile top bar and dropdown.
- Check the profile card header.
