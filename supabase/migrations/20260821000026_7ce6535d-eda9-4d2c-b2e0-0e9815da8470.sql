
-- Final security hardening: Fix remaining excessive function permissions
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM anon;

GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;
