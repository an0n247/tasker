# Plan: Verify and enforce consistent "Noble Gain" rebranding

The user wants to ensure the "Noble Gain" rebrand is applied consistently across all routes, components, and templates, following the recent visual updates.

## Proposed Changes

### 1. Unified Logo Text Styling
- The "Noble" part of the logo text should consistently use the `text-foreground` class (instead of hardcoded colors like `#002d26`) to ensure visibility in both light and dark modes.
- The "Gain" part should consistently use the gold color `#e6c17a`.
- Verify and update `src/routes/__root.tsx` (ErrorComponent) and any other missed occurrences.

### 2. Branding Alignment in Metadata and OG Assets
- Update `src/routes/api/public/og.tsx` to use the correct brand colors (Noble Gain deep green/gold) instead of the previous violet/indigo gradient.
- Ensure the SVG in `og.tsx` correctly represents the "Noble Gain" brand identity.

### 3. Clean up legacy brand identifiers
- While the previous search didn't find "Earn Pal" in the source code, there were some storage keys and plan references. I will double-check for any hidden instances in constants or configuration files.
- Update `src/routes/__root.tsx` where legacy storage keys like `earn-pal-remember-me` or `earn-pal-theme` might still be in use.

### 4. Branded Email Templates
- The user mentioned email templates. I need to check if there are any custom email templates in the repository or defined in database functions.

## Technical Details

### `src/routes/__root.tsx`
- Update `ErrorComponent` logo text styling to match `Navigation.tsx`: `text-[#002d26]` -> `text-foreground`.
- Update `storageKey` in `ThemeProvider` from `earn-pal-theme` to `noble-gain-theme`.
- Update cleanup code for legacy session flags.

### `src/routes/api/public/og.tsx`
- Change `grad1` colors to match Noble Gain: `#7C3AED` -> `#002d26`, `#4C1D95` -> `#001a16`.
- Ensure the text "NOBLE GAIN" is styled correctly within the SVG.

### Database Functions (Email)
- Inspect `src/integrations/supabase/client.ts` or `lovable--run_sql` to check for email template definitions that might need rebranding.

## Verification Plan

### Automated Checks
- `rg "text-\[#002d26\]"` to find any remaining hardcoded logo text colors.
- `rg "earn-pal"` to find legacy storage keys or names.

### Manual Verification
- Verify logo visibility in dark mode on Error pages.
- Verify OG image generation by visiting `/api/public/og`.
