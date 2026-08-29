# Plan: Move VAST Ad Config to Environment Variables

Move the VAST ad tag URL and the interstitial delay timing from hardcoded constants in the `VideoAdInterstitial` component to environment variables. This allows for configuration changes without redeploying code.

## User Review Required

> [!IMPORTANT]
> To adjust these values, you will need to set the following environment variables in your deployment settings:
> - `VITE_VAST_AD_TAG_URL`: The URL for the VAST ad tag.
> - `VITE_VIDEO_AD_DELAY_MS`: The delay in milliseconds before the interstitial appears (e.g., `3000` for 3 seconds).

## Technical Details

### Frontend Changes

- **Video Ad Interstitial Component**:
  - Replace hardcoded `VAST_TAG_URL` with `import.meta.env.VITE_VAST_AD_TAG_URL` (with the current URL as a fallback).
  - Replace hardcoded `3000`ms delay in `useEffect` with `Number(import.meta.env.VITE_VIDEO_AD_DELAY_MS) || 3000`.
  - Ensure the SDK URL remains stable but can also be overridden if needed.

### Verification Plan

- **Code Review**: Verify that the environment variables are correctly accessed and fallbacks are in place.
- **Runtime Check**: Use a Playwright script to verify the ad still triggers after the expected delay (default or configured).
