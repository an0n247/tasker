-- RLS for avatars bucket
-- Allow authenticated users to read any avatar (for social features)
CREATE POLICY "Allow authenticated read" ON storage.objects 
FOR SELECT TO authenticated 
USING (bucket_id = 'avatars');

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Allow authenticated upload" ON storage.objects 
FOR INSERT TO authenticated 
WITH CHECK (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Allow users to update/delete their own avatar
CREATE POLICY "Allow individual update" ON storage.objects 
FOR UPDATE TO authenticated 
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Allow individual delete" ON storage.objects 
FOR DELETE TO authenticated 
USING (bucket_id = 'avatars' AND (storage.foldername(name))[1] = auth.uid()::text);
