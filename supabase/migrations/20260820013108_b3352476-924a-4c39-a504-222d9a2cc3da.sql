
-- Drop existing function first to change return type or signature if needed
DROP FUNCTION IF EXISTS public.claim_welcome_bonus(_user_id uuid);

-- Add social handles columns to profiles table if they don't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS twitter_handle TEXT,
ADD COLUMN IF NOT EXISTS facebook_handle TEXT,
ADD COLUMN IF NOT EXISTS telegram_handle TEXT,
ADD COLUMN IF NOT EXISTS instagram_handle TEXT;

-- Re-create the referral bonus logic to require social handles
CREATE OR REPLACE FUNCTION public.claim_welcome_bonus(_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile record;
    v_referral_points_referrer integer := 75;
    v_referral_points_referee integer := 50;
BEGIN
    -- Get user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = _user_id;
    
    IF v_profile IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Profile not found');
    END IF;

    IF v_profile.has_claimed_welcome_bonus THEN
        RETURN json_build_object('success', false, 'message', 'Bonus already claimed');
    END IF;

    -- CHECK FOR SOCIAL HANDLES (REFEREE MUST COMPLETE THIS)
    IF v_profile.twitter_handle IS NULL OR v_profile.twitter_handle = '' OR
       v_profile.telegram_handle IS NULL OR v_profile.telegram_handle = '' THEN
        RETURN json_build_object('success', false, 'message', 'Please complete your social profiles (Twitter and Telegram at minimum) to be eligible for the bonus.');
    END IF;

    -- Mark as claimed
    UPDATE public.profiles SET has_claimed_welcome_bonus = true WHERE id = _user_id;

    -- Record transaction for referee
    INSERT INTO public.points_transactions (user_id, amount, type, description)
    VALUES (_user_id, v_referral_points_referee, 'referral_bonus', 'Welcome bonus for joining via referral');

    -- If there's a referrer, credit them too
    IF v_profile.referred_by IS NOT NULL THEN
        -- Check if referrer exists
        IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_profile.referred_by) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
            VALUES (v_profile.referred_by, v_referral_points_referrer, 'referral_bonus', 'Referral bonus for inviting ' || COALESCE(v_profile.username, 'a new user'), _user_id);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'message', 'Welcome bonus claimed successfully!');
END;
$$;
