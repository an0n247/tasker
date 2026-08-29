# Plan: Robust VAST Video Ad Implementation

Fixing the VAST ad player initialization and point crediting flow to ensure professional video ads work reliably with the provided tag.

## Proposed Changes

### Database & Backend
- Harden `record_video_watch` to prevent potential double-counting or unauthorized access.
- Ensure `video_ad_progress` and `task_submissions` are correctly updated when the final ad in a series is watched.

### UI & UX
#### VastPlayer Improvements
- Update `VastPlayer.tsx` to handle IMA SDK initialization more robustly.
- Add event listeners for `CONTENT_RESUME_REQUESTED` and `ALL_ADS_COMPLETED` to ensure the modal knows exactly when an ad finishes.
- Implement a fallback for `ads-error` so users aren't stuck behind a loading spinner if a tag fails to fill.

#### VastAdModal Enhancements
- Add a visible countdown and status indicator.
- Ensure points are credited immediately via a success toast.
- Prevent accidental closing during ad playback.

### Security
- Secure the `record_video_watch` function with `SECURITY DEFINER` and proper search path to prevent search path hijacking.
- Revoke public execution rights on sensitive functions.

## Technical Details
- **IMA SDK**: Using Google Interactive Media Ads (IMA) SDK via `videojs-ima`.
- **VAST Tag**: `https://s.magsrv.com/v1/vast.php?idzone=6006964`
- **Frontend**: React 19, Video.js 8, Tailwind CSS.

## Verification Plan
- **Headless Testing**: Simulate ad completion via Playwright by intercepting Video.js events.
- **Visual Check**: Verify the player mounts correctly in the modal and shows the "Loading Ad" overlay until playback starts.
- **Flow Check**: Verify the `record_video_watch` RPC returns the correct completion status and points are awarded to the user's profile.
