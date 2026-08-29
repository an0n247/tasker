
-- Fix excessive function permissions identified by the security linter
REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM anon;

-- Ensure these functions are strictly authenticated
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;

-- Revoke all on generic helper functions from public access
REVOKE ALL ON FUNCTION public.update_updated_at_column() FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column() TO service_role;
