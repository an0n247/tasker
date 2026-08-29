-- 1. analytics_events: remove anonymous-row visibility from public policy
DROP POLICY IF EXISTS "Allow users to view their own events" ON public.analytics_events;
CREATE POLICY "Allow users to view their own events"
ON public.analytics_events FOR SELECT TO authenticated
USING (auth.uid() = user_id);

-- 2. app_settings: only expose non-sensitive public keys to signed-in users
DROP POLICY IF EXISTS "Allow read access for authenticated users" ON public.app_settings;
CREATE POLICY "Authenticated users can read public settings"
ON public.app_settings FOR SELECT TO authenticated
USING (key IN ('welcome_bonus_enabled','welcome_bonus_amount_referee','welcome_bonus_amount_referrer','welcome_bonus_required_socials'));

-- 3. notifications: add WITH CHECK to prevent reassigning rows
DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
ON public.notifications FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 4. video_ad_progress: add WITH CHECK
DROP POLICY IF EXISTS "Users can update their own watch count" ON public.video_ad_progress;
CREATE POLICY "Users can update their own watch count"
ON public.video_ad_progress FOR UPDATE TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. Tighten EXECUTE on SECURITY DEFINER functions
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM authenticated, anon;
REVOKE EXECUTE ON FUNCTION public.lookup_login_email(text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.check_referral_code(text, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.claim_daily_reward(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.submit_task(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.record_video_watch(uuid, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.redeem_reward(uuid) FROM anon;

-- 6. claim_welcome_bonus must only run for the caller
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
    v_duplicate_id uuid;
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: You can only claim the bonus for your own account.');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;

    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    IF v_twitter_clean IS NOT NULL AND v_twitter_clean != '' AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;

    IF v_telegram_clean IS NOT NULL AND v_telegram_clean != '' AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    IF v_twitter_clean IS NULL OR v_twitter_clean = '' OR
       v_telegram_clean IS NULL OR v_telegram_clean = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram) to claim the bonus.');
    END IF;

    SELECT id INTO v_duplicate_id FROM public.profiles
    WHERE id != _user_id
    AND (
        (twitter_handle IS NOT NULL AND TRIM(LEADING '@' FROM twitter_handle) = v_twitter_clean) OR
        (telegram_handle IS NOT NULL AND TRIM(LEADING '@' FROM telegram_handle) = v_telegram_clean) OR
        (instagram_handle IS NOT NULL AND TRIM(LEADING '@' FROM instagram_handle) = v_instagram_clean) OR
        (facebook_handle IS NOT NULL AND facebook_handle = v_facebook_clean)
    )
    LIMIT 1;

    IF v_duplicate_id IS NOT NULL THEN
        INSERT INTO public.fraud_flags (user_id, type, severity, details)
        VALUES (_user_id, 'social_duplicate', 'high', jsonb_build_object(
            'duplicate_user_id', v_duplicate_id,
            'twitter', v_twitter_clean,
            'telegram', v_telegram_clean
        ));
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    UPDATE public.profiles SET
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    IF v_profile.referred_by IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_welcome_bonus(uuid) TO authenticated;