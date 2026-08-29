-- 1) Admin points adjustment: derive caller from auth.uid(), drop spoofable p_admin_id
DROP FUNCTION IF EXISTS public.handle_admin_points_adjustment(uuid, uuid, integer, text, text);

CREATE OR REPLACE FUNCTION public.handle_admin_points_adjustment(p_target_user_id uuid, p_amount integer, p_action_type text, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_admin_id uuid := auth.uid();
    v_transaction_id UUID;
    v_final_amount INTEGER;
BEGIN
    -- Security check: the actual caller must be an admin
    IF v_admin_id IS NULL OR NOT public.has_role(v_admin_id, 'admin') THEN
        RAISE EXCEPTION 'Unauthorized: Only admins can adjust points';
    END IF;

    IF p_action_type = 'credit' THEN
        v_final_amount := ABS(p_amount);
    ELSE
        v_final_amount := -ABS(p_amount);
    END IF;

    INSERT INTO public.points_transactions (user_id, amount, type, description, status)
    VALUES (p_target_user_id, v_final_amount, 'adjustment', 'Admin adjustment: ' || p_reason, 'completed')
    RETURNING id INTO v_transaction_id;

    UPDATE public.profiles
    SET points_balance = points_balance + v_final_amount,
        updated_at = NOW()
    WHERE id = p_target_user_id;

    INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
    VALUES (p_target_user_id, v_final_amount, 'Admin Adjustment: ' || p_reason, 'manual_admin_action');

    INSERT INTO public.admin_audit_logs (admin_id, action_type, target_table, target_id, new_data)
    VALUES (v_admin_id, 'points_adjustment', 'profiles', p_target_user_id,
        jsonb_build_object('amount', v_final_amount, 'reason', p_reason, 'transaction_id', v_transaction_id));

    INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
    VALUES (p_target_user_id, 'Points Adjusted',
        'Your points balance has been adjusted by ' || v_final_amount || ' points. Reason: ' || p_reason,
        'points', v_transaction_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_admin_points_adjustment(uuid, integer, text, text) TO service_role;

-- 2) Lock down role-management RPCs: app manages roles via the verified admin server function only
REVOKE EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) FROM authenticated, anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) FROM authenticated, anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_role(uuid, public.app_role) TO service_role;
GRANT EXECUTE ON FUNCTION public.remove_role(uuid, public.app_role) TO service_role;

-- 3) Revoke direct client execution of internal-only functions
REVOKE EXECUTE ON FUNCTION public.sync_points_balance(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_profile_complete(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.has_completed_social_profile(uuid) FROM PUBLIC, anon, authenticated;

-- 4) Verified video-watch sessions (private; only definer RPCs manage rows)
CREATE TABLE IF NOT EXISTS public.video_watch_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    min_watch_seconds integer NOT NULL DEFAULT 10,
    expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '10 minutes'),
    consumed boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

GRANT ALL ON public.video_watch_sessions TO service_role;
ALTER TABLE public.video_watch_sessions ENABLE ROW LEVEL SECURITY;
-- No policies: direct client access is denied; only security-definer RPCs manage rows.

CREATE OR REPLACE FUNCTION public.start_video_watch_session(_user_id uuid, _task_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task record;
    v_session_id uuid;
    v_min_seconds integer := 10;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT * INTO v_task FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos' AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified') THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- Invalidate any previous unused sessions for this user/task
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE user_id = _user_id AND task_id = _task_id AND consumed = false;

    INSERT INTO public.video_watch_sessions (user_id, task_id, min_watch_seconds)
    VALUES (_user_id, _task_id, v_min_seconds)
    RETURNING id INTO v_session_id;

    RETURN json_build_object('success', true, 'session_id', v_session_id, 'min_watch_seconds', v_min_seconds);
END;
$function$;

REVOKE ALL ON FUNCTION public.start_video_watch_session(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_video_watch_session(uuid, uuid) TO service_role;

-- 5) record_video_watch now requires a valid single-use watch session with server-enforced minimum duration
DROP FUNCTION IF EXISTS public.record_video_watch(uuid, uuid);

CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid, _session_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
    v_consumed_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- Verify the server-issued watch session exists for this user/task
    IF NOT EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND user_id = _user_id AND task_id = _task_id
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Invalid watch session. Please start the ad again.');
    END IF;

    IF EXISTS (SELECT 1 FROM public.video_watch_sessions WHERE id = _session_id AND expires_at < v_now) THEN
        RETURN json_build_object('success', false, 'message', 'Watch session expired. Please start the ad again.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.video_watch_sessions
        WHERE id = _session_id AND v_now < created_at + (min_watch_seconds || ' seconds')::interval
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Please watch the full ad before claiming progress.');
    END IF;

    -- Atomically consume the session (single-use, race-safe)
    UPDATE public.video_watch_sessions SET consumed = true
    WHERE id = _session_id AND consumed = false
    RETURNING id INTO v_consumed_id;

    IF v_consumed_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'This watch session was already used.');
    END IF;

    IF NOT public.has_completed_social_profile(_user_id) THEN
        RETURN json_build_object('success', false, 'message', 'Complete your social profile verification before performing tasks.');
    END IF;

    SELECT * INTO v_task_record FROM public.tasks
    WHERE id = _task_id AND is_active = true AND category = 'Videos' AND video_ad_count > 0;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Invalid video task.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.task_submissions
        WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified'
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT (user_id, task_id) DO UPDATE
        SET status = 'verified', created_at = v_now;

        DELETE FROM public.video_ad_progress WHERE user_id = _user_id AND task_id = _task_id;

        RETURN json_build_object(
            'success', true,
            'completed', true,
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'completed', false,
        'watch_count', v_progress_record.watch_count,
        'message', 'Progress: ' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ' ads watched.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.record_video_watch(uuid, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid, uuid) TO service_role;