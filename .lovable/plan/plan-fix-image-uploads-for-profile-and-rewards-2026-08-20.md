# Plan - Fix Image Uploads for Profile and Rewards

The user is experiencing errors when uploading images to their profile and reward pages. Investigation revealed that RLS is enabled on the `storage.buckets` table but no policies exist, preventing users from accessing the buckets. Additionally, the `RewardsManager` is incorrectly using the `avatars` bucket with a path that violates the existing RLS policies.

## Proposed Changes

### Database & Storage
- Create a new storage bucket named `rewards`.
- Add RLS policies to `storage.buckets`:
    - Allow `authenticated` and `anon` users to view buckets.
- Add RLS policies to `storage.objects`:
    - For `rewards` bucket:
        - Allow `authenticated` users with `admin` role to `INSERT`, `UPDATE`, and `DELETE`.
        - Allow all users (`public`) to `SELECT`.
    - For `avatars` bucket:
        - Keep existing user-specific folder policies.
        - Add a policy allowing `admin` users to manage all avatars (useful for moderation).
- Set both `avatars` and `rewards` buckets to `public` so their contents can be served via standard public URLs.

### Frontend - Admin Panel
- Update `src/components/admin/RewardsManager.tsx` to:
    - Use the new `rewards` bucket.
    - Use a simpler path (e.g., `rewards/filename`) now that the policy allows admin access.

### Frontend - Profile
- Verify `src/routes/_authenticated.profile.tsx` is using the correct bucket and path (it currently seems correct, but the bucket visibility fix should resolve the issue).

## Technical Details

### SQL Migration
```sql
-- 1. Create rewards bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('rewards', 'rewards', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Ensure avatars is public too
UPDATE storage.buckets SET public = true WHERE id = 'avatars';

-- 2. Enable RLS on storage tables (already enabled, but good to ensure)
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Buckets policies
DROP POLICY IF EXISTS "Public can view buckets" ON storage.buckets;
CREATE POLICY "Public can view buckets" ON storage.buckets FOR SELECT TO public USING (true);

-- 4. Rewards objects policies
DROP POLICY IF EXISTS "Admins can manage rewards" ON storage.objects;
CREATE POLICY "Admins can manage rewards" 
ON storage.objects 
FOR ALL 
TO authenticated 
USING (
  bucket_id = 'rewards' AND 
  public.has_role(auth.uid(), 'admin')
)
WITH CHECK (
  bucket_id = 'rewards' AND 
  public.has_role(auth.uid(), 'admin')
);

DROP POLICY IF EXISTS "Anyone can view rewards" ON storage.objects;
CREATE POLICY "Anyone can view rewards" 
ON storage.objects 
FOR SELECT 
TO public 
USING (bucket_id = 'rewards');

-- 5. Enhanced Avatars policies for Admins
DROP POLICY IF EXISTS "Admins can manage all avatars" ON storage.objects;
CREATE POLICY "Admins can manage all avatars" 
ON storage.objects 
FOR ALL 
TO authenticated 
USING (
  bucket_id = 'avatars' AND 
  public.has_role(auth.uid(), 'admin')
)
WITH CHECK (
  bucket_id = 'avatars' AND 
  public.has_role(auth.uid(), 'admin')
);
```

### RewardsManager.tsx Change
Modify `handleImageUpload` to use `rewards` bucket.
