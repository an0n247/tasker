# Plan - Limit Video Ad Interstitial to Task Click Only

The current implementation of the `VideoAdInterstitial` component triggers automatically when a user navigates to the `/dashboard` or `/earn` routes after a short delay. The user wants this interstitial to play ONLY when they explicitly click the task designed for it, rather than playing on site opening or route entry.

## Proposed Changes

### Interstitial Logic
- Remove the `useEffect` hook from `VideoAdInterstitial.tsx` that automatically triggers the ad based on route changes and session storage flags.
- Introduce a global event or a custom hook/state that allows manual triggering of the `VideoAdInterstitial` from other components.

### Task Integration
- Update the "Watch Ad" task handling in `src/routes/_authenticated.earn.tsx`.
- Instead of using the `VastAdModal` (which uses `videojs-ima`), provide an option to trigger the global `VideoAdInterstitial` (which uses the direct Google IMA SDK implementation) if preferred, or ensure the "Videos" category specifically triggers the intended interstitial experience.
- *Clarification needed:* There are currently two ad implementations: `VideoAdInterstitial` (root-level, direct IMA SDK) and `VastAdModal` (modal-based, Video.js IMA). The user specifically referred to the "video ad interstitial" implemented recently. I will modify the root interstitial to be triggerable on demand.

### Global Trigger Mechanism
- Create a simple singleton or use a custom event (`window.dispatchEvent`) to trigger the interstitial. This avoids complex state management for a simple "show ad" command.

## Technical Details

### `src/components/VideoAdInterstitial.tsx`
- Remove the route-based `useEffect`.
- Add a custom event listener for `play-interstitial-ad`.
- The event will pass the VAST URL if different from the default.

### `src/routes/_authenticated.earn.tsx`
- In the task click handler for "Videos", dispatch the `play-interstitial-ad` event.
- Pass the task's `vast_tag_url` to the event.

### `src/routes/__root.tsx`
- Keep the component mounted at the root.

## User Review Required

> [!IMPORTANT]
> You currently have two different video ad systems:
> 1. A **Modal Player** (`VastAdModal`) that opens when you click tasks on the "Earn" page.
> 2. A **Fullscreen Interstitial** (`VideoAdInterstitial`) that was recently added to play automatically on the Dashboard.
>
> I will change the Fullscreen Interstitial so it **no longer plays automatically** on the Dashboard. Instead, I will hook it up so that clicking a "Watch Ad" task on the Earn page triggers the high-quality Fullscreen Interstitial instead of the smaller modal. Is this the behavior you want?
