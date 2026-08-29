# Social Edit Page Enhancement Plan

The user wants to improve the social handle editing experience in the profile settings. Social platform base URLs will be displayed as uneditable labels, and users will only input their username/handle. The UI will also include instant inline verification indicators.

## Proposed Changes

### 1. Profile Page (`src/routes/_authenticated.profile.tsx`)
- Update the social handle input fields (Twitter, Telegram, Facebook, Instagram) in the edit form.
- Implement a layout where the platform's base URL (e.g., `https://facebook.com/`) is shown as a fixed prefix (using a `span` or a decorative `div`).
- Modify the inputs to only accept the username part.
- Add an "instant inline link verification" display that shows the full profile URL and a confirmation icon/text as the user types.
- Ensure the state management correctly handles stripping/adding prefixes when saving to the database.

### 2. Social Media Handle Logic
- Standardize the base URLs for each platform:
  - Twitter/X: `https://x.com/`
  - Telegram: `https://t.me/`
  - Facebook: `https://facebook.com/`
  - Instagram: `https://instagram.com/`
- Add validation to ensure users don't paste full URLs into the username field (auto-strip if they do).

## Technical Details
- **UI Components**: Use Flexbox to align the uneditable prefix with the input.
- **State Handling**: The `useState` variables (`twitter`, `facebook`, etc.) will store only the username. The prefix will be hardcoded in the UI.
- **Verification UI**: A small indicator below or beside the input showing the generated link and a status icon (e.g., a green checkmark if valid format).
- **Database Consistency**: The existing `profiles` table stores these handles. We will maintain the current storage format (usually just the handle) but ensure the UI makes it clear how the full link is constructed.

## User Review Required
> [!IMPORTANT]
> The user mentioned showing the "profile name" during verification. Since we cannot actually fetch profile names from external social APIs without complex integrations/OAuth, we will show the *generated profile URL* as a way to "verify" what the user is entering. If the user meant something else by "show the profile name", please clarify.
