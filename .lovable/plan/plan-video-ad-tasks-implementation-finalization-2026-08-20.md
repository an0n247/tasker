# Plan: Video Ad Tasks Implementation Finalization

The video ad system is implemented with VAST support using Google IMA SDK. Users watch a specific number of ads to complete a task and earn points.

## User Review

- **VAST Ad Player**: A professional player integrated with Google IMA SDK to handle VAST tags.
- **Task Management**: Admins can create video tasks, specifying the number of ads (e.g., 10) and an optional VAST URL.
- **Reward Logic**: Points are awarded automatically upon watching the required number of ads.
- **Security**: Backend functions are hardened to prevent unauthorized point claims.

## Technical Details

- **Database**:
    - `tasks.vast_tag_url`: Stores the VAST XML source.
    - `video_ad_progress`: Tracks `watch_count` per user/task.
    - `record_video_watch` RPC: Atomic increment and reward logic.
- **Frontend**:
    - `VastPlayer.tsx`: Wraps `video.js` and `videojs-ima`.
    - `VastAdModal.tsx`: Manages the ad lifecycle (loading, playing, completion).
    - `_authenticated.earn.tsx`: UI for task progress and triggering the player.
- **Security**:
    - `record_video_watch` uses `SECURITY DEFINER` with `SET search_path = public` and checks `auth.uid()`.
    - Permissions revoked from `PUBLIC` and granted only to `authenticated`.
