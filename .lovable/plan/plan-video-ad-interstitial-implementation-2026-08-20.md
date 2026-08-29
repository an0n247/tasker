# Plan: Video Ad Interstitial Implementation

Implement a standalone video ad interstitial component using the Google IMA SDK, integrated at the app root to provide a seamless, non-blocking ad experience.

## User Review Required

> [!IMPORTANT]
> This interstitial will be mounted at the app root. Should it be triggered by specific user actions (like navigating to certain pages) or at timed intervals? I will implement the component first; we can wire up the trigger logic in the next step.

## Proposed Changes

### Components

#### [CREATE] `src/components/VideoAdInterstitial.tsx`
- Dynamically loads the IMA SDK script.
- Renders a fixed, fullscreen overlay with a dark backdrop.
- Uses the provided VAST tag: `https://s.magsrv.com/v1/vast.php?idzone=6006924`.
- Implements silent failure logic: if the ad fails to load or the response is empty, the overlay simply closes.
- Styles match the Earn Pal dark-mode aesthetic (Violet-600 highlights, deep dark backgrounds).

### Routing & Layout

#### [UPDATE] `src/routes/__root.tsx`
- Mount the `VideoAdInterstitial` component within the root layout to ensure it's available globally.

## Technical Details

- **IMA SDK**: Dynamic script loading ensures the SDK is only fetched when needed, avoiding initial load overhead.
- **Error Handling**: `adsManager` error events will trigger a `handleClose` function to ensure the UI is never locked by a failed ad.
- **Styling**: Tailwind CSS for the overlay (fixed, inset-0, bg-black/90, flex, items-center, justify-center).

## Verification Plan

### Automated Tests
- Run Playwright to verify the IMA SDK script is appended to the document.
- Verify the interstitial container renders (hidden by default).
- Simulate ad events (start/complete) if possible, or verify silent closure on mock error.

### Manual Verification
- Check the preview for the fullscreen overlay presence when triggered.
- Verify that closing the ad returns the user to the underlying page without errors.
