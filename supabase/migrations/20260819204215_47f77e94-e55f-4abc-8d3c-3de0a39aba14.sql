
-- Set search_path and restrict access for internal functions
ALTER FUNCTION public.notify_on_points_transaction() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.notify_on_points_transaction() FROM PUBLIC;

ALTER FUNCTION public.handle_new_user() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;

ALTER FUNCTION public.update_points_balance_on_task_status_change() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.update_points_balance_on_task_status_change() FROM PUBLIC;

ALTER FUNCTION public.log_task_status_change() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.log_task_status_change() FROM PUBLIC;

ALTER FUNCTION public.log_user_task_activity() SET search_path = public;
REVOKE EXECUTE ON FUNCTION public.log_user_task_activity() FROM PUBLIC;

-- Functions that need to be callable by authenticated users but still need search_path
ALTER FUNCTION public.claim_daily_reward(uuid) SET search_path = public;
ALTER FUNCTION public.has_role(uuid, app_role) SET search_path = public;
ALTER FUNCTION public.submit_task(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.increment_referral_clicks(text) SET search_path = public;
ALTER FUNCTION public.get_user_email_by_username(text) SET search_path = public;

-- Admin functions - ensure they check admin role
ALTER FUNCTION public.assign_role(uuid, app_role) SET search_path = public;
ALTER FUNCTION public.remove_role(uuid, app_role) SET search_path = public;

-- Note: The linter will still warn about functions callable by signed-in users 
-- if they are SECURITY DEFINER. This is expected for APIs that need elevated 
-- privileges to update balances or check roles.
