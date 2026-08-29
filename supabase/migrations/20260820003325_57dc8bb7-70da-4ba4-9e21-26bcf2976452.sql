-- 1. Buckets policies (Allowing SELECT so client can find bucket)
DROP POLICY IF EXISTS "Public can view buckets" ON storage.buckets;
CREATE POLICY "Public can view buckets" ON storage.buckets FOR SELECT TO public USING (true);

-- 2. Rewards objects policies
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

-- 3. Enhanced Avatars policies for Admins
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