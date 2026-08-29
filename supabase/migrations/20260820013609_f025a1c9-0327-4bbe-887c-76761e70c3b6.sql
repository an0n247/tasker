-- Secure the claim_welcome_bonus function to only be executable by authenticated users
-- and revoke public access to prevent potential abuse.

REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM public;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO service_role;