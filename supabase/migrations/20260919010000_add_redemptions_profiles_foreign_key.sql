-- Add foreign key constraint from redemptions(user_id) to profiles(id)
-- so PostgREST schema cache can recognize the relationship.

DO $$
BEGIN
    -- Check if constraint to profiles already exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'redemptions_user_id_profiles_fkey'
        AND table_name = 'redemptions'
    ) THEN
        -- Safely add foreign key to public.profiles
        ALTER TABLE public.redemptions
        ADD CONSTRAINT redemptions_user_id_profiles_fkey
        FOREIGN KEY (user_id) REFERENCES public.profiles(id)
        ON DELETE CASCADE;
    END IF;
END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
