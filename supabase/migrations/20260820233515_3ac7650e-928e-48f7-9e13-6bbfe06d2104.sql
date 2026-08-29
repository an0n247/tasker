-- Revoke public execute on all public functions by default
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Revoke from existing functions specifically mentioned by linter or likely candidates
REVOKE EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) FROM PUBLIC;

-- Grant execute back to authenticated users for functions they need
GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(TEXT, UUID) TO authenticated;

-- Ensure all functions have search_path set
ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public;
ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
ALTER FUNCTION public.check_referral_code(TEXT, UUID) SET search_path = public;
