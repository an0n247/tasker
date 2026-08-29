
-- Add INSERT policy for authenticated users to the notifications table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' 
        AND policyname = 'Users can insert notifications for others during system actions'
    ) THEN
        CREATE POLICY "Users can insert notifications for others during system actions"
        ON public.notifications
        FOR INSERT
        TO authenticated
        WITH CHECK (true);
    END IF;
END
$$;

-- Ensure authenticated role has INSERT grant
GRANT INSERT ON public.notifications TO authenticated;
