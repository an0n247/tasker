# Plan: Implement VAST Ad Tag for Video Tasks

The goal is to implement a specific VAST ad tag (`https://s.magsrv.com/v1/vast.php?idzone=6006964`) for video tasks and ensure it correctly credits points to users after a complete watch using the Google IMA SDK.

## Technical Details

- **VAST URL**: `https://s.magsrv.com/v1/vast.php?idzone=6006964`
- **Frontend**: Update `src/routes/_authenticated.earn.tsx` and `src/components/VastPlayer.tsx` to handle the specific requirements of this ad tag.
- **Admin**: Ensure the Admin Panel's `TasksManager.tsx` can correctly store and manage this VAST URL.
- **Verification**: Use a headless browser to simulate a user watching the ad and verify point crediting.

## Implementation Steps

### 1. Verification of Schema and Components
- Confirm `tasks` table has `vast_tag_url`.
- Verify `VastPlayer.tsx` and `VastAdModal.tsx` are correctly using `videojs-ima`.

### 2. Admin Panel Setup
- In `src/components/admin/TasksManager.tsx`, ensure the VAST Tag URL is correctly handled in the form.

### 3. Earn Page Integration
- In `src/routes/_authenticated.earn.tsx`, ensure that tasks with a `vast_tag_url` trigger the `VastAdModal`.
- Verify the `onComplete` callback correctly calls the `record_video_watch` RPC.

### 4. VAST Player Hardening
- Update `src/components/VastPlayer.tsx` to ensure it handles the specific VAST tag provided.
- Ensure the `ads-alladscompleted` event is reliably triggered for this specific tag.

### 5. Manual Seed for Testing
- Create a test video task with the provided VAST URL using a SQL migration or the Admin UI.

### 6. Verification
- Use Playwright to:
    1. Login as a user.
    2. Navigate to the Earn page.
    3. Click "Watch Ad" for the VAST task.
    4. Wait for ad completion (or simulate it if possible).
    5. Verify the `record_video_watch` RPC was called and points were updated.
