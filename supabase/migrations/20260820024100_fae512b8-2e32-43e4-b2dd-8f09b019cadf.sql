DROP FUNCTION IF EXISTS public.process_redemption_status_change(uuid, text);
REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated, service_role;
