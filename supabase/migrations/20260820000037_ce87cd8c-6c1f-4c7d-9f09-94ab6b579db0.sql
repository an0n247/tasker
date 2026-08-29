-- Internal Triggers (should only be executable by system)
REVOKE ALL ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.notify_on_points_transaction() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.log_task_status_change() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.log_task_status_change() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.handle_admin_audit_log() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.handle_admin_audit_log() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.log_user_task_activity() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.log_user_task_activity() TO service_role, postgres;

REVOKE ALL ON FUNCTION public.update_user_points_balance() FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_user_points_balance() TO service_role, postgres;

-- Admin-only functions (checked via has_role, but limiting execution is safer)
REVOKE ALL ON FUNCTION public.assign_role(UUID, public.app_role) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.assign_role(UUID, public.app_role) TO service_role, postgres;

REVOKE ALL ON FUNCTION public.remove_role(UUID, public.app_role) FROM PUBLIC, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.remove_role(UUID, public.app_role) TO service_role, postgres;
