# Plan - Adjust Auth Card Height

The user reported that the authentication card appears "unnecessarily tall". I will refine the vertical spacing, padding, and font sizes within the auth card to create a more compact and balanced appearance across all authentication states (login, signup, password reset, and verification).

## Proposed Changes

### 1. Refine Spacing in Auth Route
- **File:** `src/routes/auth.tsx`
- **Actions:**
    - Reduce card padding from `p-6 sm:p-9` to `p-6 sm:p-8` (and potentially `sm:py-7` for a tighter vertical feel).
    - Decrease vertical margins for headings (`mt-6` -> `mt-4`), descriptions (`mt-3` -> `mt-2`), and separators (`my-6` -> `my-4`).
    - Adjust the Google login button's top margin (`mt-7` -> `mt-5`).
    - Tighten form element spacing by using `space-y-4` consistently instead of `space-y-5`.
    - Slightly reduce the main heading size from `text-4xl` to `text-3xl` for better proportions within the card.
    - Apply equivalent spacing reductions to the email verification view to maintain consistency.

## Technical Details
- Using Tailwind utility classes to adjust margins (`mt-*`, `my-*`) and padding (`p-*`).
- Updating typography classes (`text-*`) to scale down prominent headers.
- Ensuring responsive behavior is preserved so the card remains accessible on smaller screens while appearing less stretched on desktops.
