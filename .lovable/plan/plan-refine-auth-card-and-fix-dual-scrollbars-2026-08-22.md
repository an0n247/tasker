# Plan: Refine Auth Card and Fix Dual Scrollbars

I will reduce the vertical footprint of the authentication card by tightening spacing and font sizes. I will also resolve the persistent dual scrollbar issue by strictly enforcing overflow behavior on the body element.

## Proposed Changes

### 1. Refine Authentication UI Spacing (`src/routes/auth.tsx`)
- **Card Padding**: Reduce from `p-6` to `p-5` (mobile) and from `sm:px-8 sm:py-7` to `sm:px-7 sm:py-6` (desktop).
- **Header**: Reduce top margin from `mt-4` to `mt-3` and font size from `text-3xl` to `text-2xl`.
- **Description**: Reduce top margin from `mt-2` to `mt-1.5`.
- **Google Button**: Reduce top margin from `mt-5` to `mt-4`.
- **Separator**: Reduce vertical margin from `my-4` to `my-3`.
- **Form Controls**:
    - Reduce vertical spacing (`space-y-4` to `space-y-3`).
    - Scale down input heights from `h-14` to `h-12`.
    - Scale down button heights from `h-14` to `h-12`.
    - Scale down `TabsList` height from `h-14` to `h-12`.
- **OTP View**: Apply similar reductions to verification screen padding, margins, and input/button heights.

### 2. Fix Dual Scrollbars (`src/styles.css`)
- Enforce `overflow-y: visible !important` on the `body` element to prevent it from creating its own scroll context when `html` is already scrollable.
- Keep `html` as the primary scroll container with `overflow-y: auto`.

## Technical Details
- Using `!important` on `body` overflow to override any library-injected styles (like Radix or Tailwind defaults) that might be re-applying `overflow: auto`.
- Maintaining accessibility by ensuring touch targets remain large enough even with reduced heights (using `h-12` instead of `h-14` is still well within standard touch target guidelines).
- Validating the layout with Playwright to ensure the dual scrollbars are gone and the card fits better on smaller viewports.
