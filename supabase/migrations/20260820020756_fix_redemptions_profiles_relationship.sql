ALTER TABLE public.redemptions DROP CONSTRAINT IF EXISTS redemptions_user_id_fkey;
ALTER TABLE public.redemptions ADD CONSTRAINT redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
GRANT SELECT ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;
