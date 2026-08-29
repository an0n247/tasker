-- Revoke EXECUTE from PUBLIC and anon for remaining sensitive functions
REVOKE EXECUTE ON FUNCTION public.lookup_login_email(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) FROM PUBLIC, anon;

-- Re-grant to authenticated roles
GRANT EXECUTE ON FUNCTION public.lookup_login_email(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) TO authenticated, service_role;
