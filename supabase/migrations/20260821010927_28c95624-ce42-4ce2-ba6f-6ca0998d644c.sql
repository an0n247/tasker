-- Restore execution permissions for core functions
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated, service_role;

-- Fix Admin access to app_settings
DROP POLICY IF EXISTS "Admins can read all settings" ON public.app_settings;
CREATE POLICY "Admins can read all settings"
ON public.app_settings FOR SELECT TO authenticated
USING (public.has_role(auth.uid(), 'admin'));

-- Ensure Admins can also update settings (missing in previous hardening)
DROP POLICY IF EXISTS "Admins can update all settings" ON public.app_settings;
CREATE POLICY "Admins can update all settings"
ON public.app_settings FOR ALL TO authenticated
USING (public.has_role(auth.uid(), 'admin'))
WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Re-grant access to user_roles for RLS evaluation
GRANT SELECT ON public.user_roles TO authenticated, service_role;
