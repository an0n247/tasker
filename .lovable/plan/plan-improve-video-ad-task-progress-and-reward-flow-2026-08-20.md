# Plan - Improve Video Ad Task Progress and Reward Flow

Ensuring the video ad task correctly tracks progress up to the 10th watch and awards the reward upon completion.

## Proposed Changes

### 1. Robust Ad URL Handling
- Update `VideoAdInterstitial.tsx` to trim the VAST URL before requesting the ad, preventing errors from leading/trailing whitespace in the database.
- Ensure the completion callback is reliably triggered.

### 2. UI Progress Verification
- Verify the `EarnPage` correctly calculates and displays the watch count (e.g., "7 / 10 Ads").
- Ensure the progress bar reflects this accurately.

### 3. Verification
- Use Playwright to simulate the video watch flow (mocking the ad completion) to ensure the `record_video_watch` RPC is called and the UI updates the count until completion.

## Technical Details
- **Component**: `src/components/VideoAdInterstitial.tsx`
- **Page**: `src/routes/_authenticated.earn.tsx`
- **Logic**: The `record_video_watch` RPC handles the server-side logic, while the frontend dispatches events to trigger the interstitial and handles the callback to update progress.

## User Review Required
> [!IMPORTANT]
> The "Watch ADS" task currently has a VAST URL with a leading space in the database. I will fix this in the code by trimming the URL, but the admin might want to clean up the database entry as well.
