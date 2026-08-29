# Plan: Add Direct Image Link Support and Fix Broken Images

The user reports that image uploads are still problematic ("still the same") and suggests allowing direct image links instead of just uploads. Additionally, the recent attempt at server-side optimization appears to have caused "broken images" because transformation parameters were appended to standard Supabase `object/public` URLs which do not support them by default.

## Proposed Changes

### 1. Fix Image Display Logic
- Remove the transformation parameters (`?width=...`) from `AvatarImage` and `img` tags across the application.
- Standardize on using the direct URL stored in the database, allowing for both Supabase-hosted images and external links.

### 2. Update Profile Management
- **File**: `src/routes/_authenticated.profile.tsx`
- **Action**: Add a "Direct Image URL" text input to the edit profile section.
- **Action**: Allow users to either upload a file (which populates the URL) or paste a link directly.
- **Action**: Ensure the "Save Changes" button persists the manually entered URL.

### 3. Update Reward Management
- **File**: `src/components/admin/RewardsManager.tsx`
- **Action**: Add an "Image URL" text input to the "Add/Edit Reward" dialog.
- **Action**: Provide a clear choice between uploading an image or pasting a direct link.
- **Action**: Ensure the reward image preview updates correctly when a link is pasted.

### 4. General Cleanup
- Update `src/routes/_authenticated.redeem.tsx` to remove the transformation parameters from reward displays.
- Keep the `avatars` and `rewards` storage buckets functional for those who still choose to upload.

## Technical Details

- **Supabase Storage**: I will revert to using standard public URLs without query parameters to ensure they resolve correctly across all tiers.
- **Database**: No schema changes are required as `profiles.avatar_url` and `rewards.image_url` are already text columns that can store any URL.
- **UI/UX**: The image URL field will be placed near the upload button to offer both options clearly.

## Constraints & Considerations
- External links must be public for the images to display.
- I will maintain the existing `ImageCropper` for uploads but ensure it doesn't interfere with manual URL entry.
