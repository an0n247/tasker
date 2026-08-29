-- Create app_settings table
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT SELECT ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
GRANT INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;

-- Enable RLS
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read access for authenticated users" 
ON public.app_settings FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Allow admin to manage settings" 
ON public.app_settings FOR ALL 
TO authenticated 
USING (public.has_role(auth.uid(), 'admin'));

-- Initial Settings
INSERT INTO public.app_settings (key, value, description)
VALUES 
('welcome_bonus_enabled', 'true'::jsonb, 'Enable or disable the welcome bonus for referred users'),
('welcome_bonus_amount_referee', '50'::jsonb, 'Amount of points given to the new user (referee)'),
('welcome_bonus_amount_referrer', '75'::jsonb, 'Amount of points given to the user who invited them (referrer)'),
('welcome_bonus_required_socials', '["twitter", "telegram"]'::jsonb, 'List of social handles required to claim the bonus')
ON CONFLICT (key) DO UPDATE SET 
    value = EXCLUDED.value,
    description = EXCLUDED.description;

-- Update claim_welcome_bonus function
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_profile record;
    v_bonus_enabled boolean;
    v_referral_points_referrer integer;
    v_referral_points_referee integer;
    v_required_socials jsonb;
    v_twitter_clean text;
    v_telegram_clean text;
    v_instagram_clean text;
    v_facebook_clean text;
BEGIN
    -- Read settings from app_settings
    SELECT (value->>0)::boolean INTO v_bonus_enabled FROM public.app_settings WHERE key = 'welcome_bonus_enabled';
    SELECT (value->>0)::integer INTO v_referral_points_referee FROM public.app_settings WHERE key = 'welcome_bonus_amount_referee';
    SELECT (value->>0)::integer INTO v_referral_points_referrer FROM public.app_settings WHERE key = 'welcome_bonus_amount_referrer';
    SELECT value INTO v_required_socials FROM public.app_settings WHERE key = 'welcome_bonus_required_socials';

    -- Defaults if settings are missing
    v_bonus_enabled := COALESCE(v_bonus_enabled, true);
    v_referral_points_referee := COALESCE(v_referral_points_referee, 50);
    v_referral_points_referrer := COALESCE(v_referral_points_referrer, 75);
    v_required_socials := COALESCE(v_required_socials, '["twitter", "telegram"]'::jsonb);

    IF NOT v_bonus_enabled THEN
        RETURN json_build_object('success', false, 'message', 'Welcome bonus program is currently disabled.');
    END IF;

    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- Clean and validate handles
    v_twitter_clean := TRIM(LEADING '@' FROM TRIM(v_profile.twitter_handle));
    v_telegram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.telegram_handle));
    v_instagram_clean := TRIM(LEADING '@' FROM TRIM(v_profile.instagram_handle));
    v_facebook_clean := TRIM(v_profile.facebook_handle);

    -- Dynamic validation based on required_socials setting
    IF ('"twitter"'::jsonb <@ v_required_socials) AND (v_twitter_clean IS NULL OR v_twitter_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Twitter profile to be eligible.');
    END IF;

    IF ('"telegram"'::jsonb <@ v_required_socials) AND (v_telegram_clean IS NULL OR v_telegram_clean = '') THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your Telegram profile to be eligible.');
    END IF;
    
    -- Format validation for Twitter
    IF (v_twitter_clean IS NOT NULL AND v_twitter_clean != '') AND NOT (v_twitter_clean ~ '^[a-zA-Z0-9_]{1,15}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Twitter handle format.');
    END IF;
    
    -- Format validation for Telegram
    IF (v_telegram_clean IS NOT NULL AND v_telegram_clean != '') AND NOT (v_telegram_clean ~ '^[a-zA-Z0-9_]{5,32}$') THEN
        RETURN json_build_object('success', false, 'message', 'Invalid Telegram handle format.');
    END IF;

    -- Prevent Duplicate Handles
    IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id != _user_id 
        AND has_claimed_welcome_bonus = true 
        AND (
            (twitter_handle IS NOT NULL AND v_twitter_clean IS NOT NULL AND twitter_handle = v_twitter_clean) OR
            (telegram_handle IS NOT NULL AND v_telegram_clean IS NOT NULL AND telegram_handle = v_telegram_clean)
        )
    ) THEN
        RETURN json_build_object('success', false, 'message', 'These social handles are already associated with another account.');
    END IF;

    -- Update handles to cleaned versions and mark as claimed
    UPDATE public.profiles SET 
        has_claimed_welcome_bonus = true,
        twitter_handle = v_twitter_clean,
        telegram_handle = v_telegram_clean,
        instagram_handle = COALESCE(v_instagram_clean, instagram_handle),
        facebook_handle = COALESCE(v_facebook_clean, facebook_handle)
    WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$function$;
