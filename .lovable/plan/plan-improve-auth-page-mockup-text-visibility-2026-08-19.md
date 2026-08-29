# Plan: Improve Auth Page Mockup Text Visibility

The current auth page mockup uses an image as a background with a gradient overlay, but the text "Join thousands of users..." has poor contrast against the colorful background image. I will improve the visibility by adjusting the overlay and text colors.

## Technical Details

### 1. Update Auth Page Mockup
- In `src/routes/auth.tsx`, I will modify the gradient overlay to be darker or more opaque to provide better contrast for the white/muted text.
- I will ensure the text uses high-contrast colors (e.g., pure white or a very light gray) on the dark gradient.
- I will potentially add a slight text shadow or adjust the font weight to improve readability.

### 2. Verification
- I will use a Playwright script to capture a new screenshot of the auth page mockup.
- I will verify that the text is clearly visible in both light and dark modes (the mockup is currently hardcoded with some colors, so I'll check its theme-responsiveness).
