# Plan: Fix Image Uploads and Visibility

The user reports failures in uploading profile avatars and reward images, as well as broken images for rewards. Investigation indicates that while storage RLS policies exist, the required `avatars` and `rewards` buckets may not have been initialized in the database.

## User Review Required
> [!IMPORTANT]
> This fix will attempt to create the necessary storage buckets if they are missing. This requires the user to be an admin to run the initialization.

## Proposed Changes

### Database (Supabase)
- Create a new migration to explicitly create the `avatars` and `rewards` buckets if they don't exist.
- Ensure `public` has SELECT access to these buckets to resolve permission issues when checking for existence.

### Frontend
- Implement a robust `StorageInit` component that runs once per session to ensure buckets are present.
- Improve error handling and user feedback in `Profile.tsx` and `RewardsManager.tsx` during uploads.
- Fix image URL resolution to handle potential path issues.

## Technical Details

### 1. Database Migration
- Add `INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;`
- Add `INSERT INTO storage.buckets (id, name, public) VALUES ('rewards', 'rewards', true) ON CONFLICT (id) DO NOTHING;`

### 2. Frontend Hardening
- Update `src/routes/_authenticated.profile.tsx` to log specific storage errors.
- Update `src/components/admin/RewardsManager.tsx` to log specific storage errors.
- Ensure `AvatarImage` and `img` tags have proper `onError` handlers to show fallback UI instead of broken icons.

## Verification Plan
1. Apply database migration.
2. Manually test profile avatar upload in the preview.
3. Manually test reward image upload in the admin panel.
4. Verify image visibility after upload.
