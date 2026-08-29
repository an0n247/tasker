-- Fix security linter warnings for record_video_watch
REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO service_role;

-- Also fix security linter warnings for submit_task (detected in previous linter output)
REVOKE ALL ON FUNCTION public.submit_task(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO service_role;
