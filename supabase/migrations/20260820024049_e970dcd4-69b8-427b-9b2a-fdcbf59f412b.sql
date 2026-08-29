GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO service_role;
REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) FROM PUBLIC;
