# Plan: Fix Auth Tabs Dark Mode Visibility

The login and signup tabs on the authentication page currently have hardcoded light-mode background colors that don't adapt to dark mode, making them difficult to see or inconsistent with the theme. I will update the `TabsList` background to use semantic theme tokens instead of a hardcoded hex value.

## Technical Details

### Frontend Changes

- **`src/routes/auth.tsx`**:
    - Update `TabsList` className to use `bg-muted` or `bg-secondary` instead of the hardcoded `bg-[#F8F9FB]`.
    - Remove the hardcoded hex background to allow the semantic theme variables from `src/styles.css` to take effect.
    - Verify that `TabsTrigger` active states (`data-[state=active]`) are correctly visible against the updated list background in both light and dark modes.

## Validation Plan

- Manually verify the authentication page (`/auth`) in both light and dark modes using the preview theme toggle.
- Confirm the `TabsList` background color changes appropriately between modes.
- Ensure the active `TabsTrigger` has sufficient contrast in both themes.
