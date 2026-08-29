-- Create a function to handle referral rewards when a new user joins
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50; -- Points awarded for a successful referral
BEGIN
    -- Find the referrer from the referrals table
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

    -- If a referrer was found, award them points
    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username
        );
        
        -- Also notify the referrer if the notification system exists
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                v_referrer_id,
                'Referral Reward!',
                'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined using your code.',
                'reward'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Attach the trigger to the profiles table (fires after handle_new_user)
DROP TRIGGER IF EXISTS on_profile_referral_reward ON public.profiles;
CREATE TRIGGER on_profile_referral_reward
    AFTER INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.reward_referrer_on_signup();

-- Ensure proper permissions
REVOKE ALL ON FUNCTION public.reward_referrer_on_signup() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO service_role;
GRANT EXECUTE ON FUNCTION public.reward_referrer_on_signup() TO postgres;
