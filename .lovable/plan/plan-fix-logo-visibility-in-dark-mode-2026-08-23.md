# Plan: Fix logo visibility in dark mode

The user wants to improve the visibility of the "Noble" part of the logo text when the app is in dark mode. Currently, it is hardcoded to a deep green (`#002d26`), which disappears against the dark background.

## Proposed Changes

### 1. Update Logo Text Styling
- Modify `src/components/Navigation.tsx` and `src/routes/index.tsx` (footer) to use semantic color tokens for the "NOBLE" part of the text.
- Replace the hardcoded `text-[#002d26]` with a class that adapts to the theme, or use `text-foreground` for the "NOBLE" part while keeping `text-[#e6c17a]` for "GAIN".

### 2. Standardize Logo Components (Optional but recommended)
- If necessary, create a shared `Logo` component to ensure consistency across the site.

## Technical Details

### `src/components/Navigation.tsx`
- Change `<span className="hidden xs:inline text-[#002d26]">Noble <span className="text-[#e6c17a]">Gain</span></span>` to something like `<span className="hidden xs:inline text-foreground dark:text-foreground">Noble <span className="text-[#e6c17a]">Gain</span></span>` or just `text-foreground`.
- Apply similar changes to mobile navigation and sidebar sections.

### `src/routes/index.tsx`
- Update the footer logo: `<span className="text-[#002d26]">NOBLE <span className="text-[#e6c17a]">GAIN</span></span>` -> `<span className="text-foreground">NOBLE <span className="text-[#e6c17a]">GAIN</span></span>`.

## Verification Plan

### Automated Tests
- Check if `text-[#002d26]` still exists in relation to the logo text using `rg`.

### Manual Verification
- Toggle dark mode in the preview and verify that "Noble" is visible (it should switch from deep green/black to white/off-white depending on the theme).
