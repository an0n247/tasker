DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.points_transactions;
  EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.points_transactions REPLICA IDENTITY FULL;