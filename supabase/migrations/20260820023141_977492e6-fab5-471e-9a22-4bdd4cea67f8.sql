-- Revoke EXECUTE from PUBLIC and anon for sensitive functions
REVOKE EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_task(UUID, UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.redeem_reward(UUID) FROM PUBLIC, anon;

-- Re-grant to specific roles
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_task(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_reward(UUID) TO authenticated, service_role;
