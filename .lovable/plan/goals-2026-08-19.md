---
name: Layout Adjustment and Mobile Fixes
description: Adjust grid layout for header/body and restrict mobile keyboard zoom.
type: design
---

## Goals
1. **Layout Adjustment**: Refine the grid and layout relationship between the header and main content to match the visual reference (sidebar/topbar/content synergy).
2. **Mobile UX**: Prevent browsers from automatically zooming in on text inputs on mobile devices by setting the font size to at least 16px.
3. **Consistency**: Ensure the glassmorphism header and sidebar offsets are correctly applied across all authenticated routes.

## Proposed Changes

### 1. Global Viewport Metadata
- Update `src/routes/__root.tsx` to include `user-scalable=no` or ensure font-sizes on inputs are large enough to prevent auto-zoom (standard approach is font-size >= 16px). Actually, the user specifically asked to "restrict unnecessary zoom when opening a keyboard", which usually happens when font-size < 16px.

### 2. Layout Grid refinement
- Review `src/routes/__root.tsx` and `src/components/Navigation.tsx`.
- The user mentioned "header and body be in a different grid". Looking at the screenshot, the header seems to be floating or misaligned on mobile, and the body content has large whitespace.
- I will adjust the `main` container in `__root.tsx` to ensure it fills the space correctly and the header in `Navigation.tsx` matches the width constraints of the content.

### 3. Mobile Navigation & Header
- Ensure the mobile header in `Navigation.tsx` is truly full-width and aligned.
- Fix any `pl-80` vs `md:pl-72` inconsistencies.

## Technical Details
- **Mobile Zoom**: Add `maximum-scale=1` to the viewport meta tag in `src/routes/__root.tsx` (carefully, as this can affect accessibility, but it's what was requested) OR better, ensure all inputs have `text-base` (16px) on mobile. I will go with the font-size fix as it's the standard best practice.
- **Grid Adjustment**: Standardize the sidebar width (72 units = 288px) and the content offset.
- **Glassmorphism**: Ensure the header `backdrop-blur` and `bg-white/80` are consistent.

## Verification Plan
- Use Playwright to check mobile viewport (390px) and verify header width.
- Check input field font sizes.
- Verify desktop layout at 1440px to ensure the sidebar/header/content grid is solid.
