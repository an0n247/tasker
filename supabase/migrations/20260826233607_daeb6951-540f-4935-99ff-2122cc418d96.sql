DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure::text AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prosecdef
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
  END LOOP;
END $$;

GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_user_notification(uuid, text, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_redemption_status_change(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_points(uuid, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_task_completions(timestamptz, timestamptz, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_repeatable_task_stats(timestamptz, timestamptz, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_profile_complete(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_points_balance(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_referral_code(text, uuid) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.lookup_login_email(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.increment_referral_clicks(text) TO authenticated, anon;