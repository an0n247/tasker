-- Allow public access to read avatars (if bucket is public or for general viewing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Public Access' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Public Access"
        ON storage.objects FOR SELECT
        USING ( bucket_id = 'avatars' );
    END IF;
END $$;

-- Allow authenticated users to upload their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can upload their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can upload their own avatar"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;

-- Allow users to update their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can update their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can update their own avatar"
        ON storage.objects FOR UPDATE
        TO authenticated
        USING (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;

-- Allow users to delete their own avatar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own avatar' AND tablename = 'objects' AND schemaname = 'storage'
    ) THEN
        CREATE POLICY "Users can delete their own avatar"
        ON storage.objects FOR DELETE
        TO authenticated
        USING (
          bucket_id = 'avatars' AND 
          (storage.foldername(name))[1] = auth.uid()::text
        );
    END IF;
END $$;
