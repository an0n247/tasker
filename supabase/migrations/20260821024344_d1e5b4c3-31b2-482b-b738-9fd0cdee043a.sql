-- Migration to handle pending referral bonuses and user completion status

-- 1. Add status to points_transactions if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'points_transactions' AND column_name = 'status') THEN
        ALTER TABLE public.points_transactions ADD COLUMN status text DEFAULT 'completed';
    END IF;
END $$;

-- 2. Update the reward_referrer_on_signup function to mark as pending
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50;
    v_new_user_bonus INTEGER := 50;
BEGIN
    -- Find the referrer
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

    -- If a referrer was found, award them points (PENDING)
    IF v_referrer_id IS NOT NULL THEN
        -- Transaction for Referrer
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username || ' (Pending profile completion)',
            'pending',
            NEW.id
        );

        -- Transaction for New User (Referee) - also pending
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
            NEW.id,
            v_new_user_bonus,
            'welcome_bonus',
            'Welcome bonus (Pending profile completion)',
            'pending',
            v_referrer_id
        );
        
        -- Notifications
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            v_referrer_id,
            'Referral Pending!',
            'You have a pending reward for referring ' || NEW.username || '. It will be available once they complete their profile.',
            'info'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Create function to check if profile is complete
CREATE OR REPLACE FUNCTION public.is_profile_complete(p_profile_id UUID)
RETURNS boolean AS $$
DECLARE
    v_profile public.profiles;
BEGIN
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_profile_id;
    
    RETURN (
        v_profile.full_name IS NOT NULL AND 
        v_profile.username IS NOT NULL AND 
        v_profile.phone_number IS NOT NULL AND 
        (v_profile.twitter_handle IS NOT NULL OR v_profile.telegram_handle IS NOT NULL OR v_profile.facebook_handle IS NOT NULL OR v_profile.instagram_handle IS NOT NULL)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- 4. Trigger function to complete pending transactions
CREATE OR REPLACE FUNCTION public.check_pending_referrals_on_update()
RETURNS TRIGGER AS $$
DECLARE
    v_complete boolean;
BEGIN
    v_complete := public.is_profile_complete(NEW.id);
    
    IF v_complete AND NOT public.is_profile_complete(OLD.id) THEN
        -- 1. Complete transactions where this user is the source (Referrer's reward)
        UPDATE public.points_transactions 
        SET status = 'completed', 
            description = REPLACE(description, ' (Pending profile completion)', '')
        WHERE source_id = NEW.id AND type = 'referral' AND status = 'pending';

        -- 2. Complete transactions where this user is the recipient (Referee's reward)
        UPDATE public.points_transactions 
        SET status = 'completed', 
            description = REPLACE(description, ' (Pending profile completion)', '')
        WHERE user_id = NEW.id AND type = 'welcome_bonus' AND status = 'pending';

        -- Notify user
        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (
            NEW.id,
            'Bonus Earned!',
            'Your welcome bonus has been credited for completing your profile!',
            'reward'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Attach update trigger
DROP TRIGGER IF EXISTS on_profile_update_check_referral ON public.profiles;
CREATE TRIGGER on_profile_update_check_referral
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.check_pending_referrals_on_update();

-- 5. Modify points balance sync to ignore pending transactions
CREATE OR REPLACE FUNCTION public.sync_points_balance()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET points_balance = (
        SELECT COALESCE(SUM(amount), 0)
        FROM public.points_transactions
        WHERE user_id = NEW.user_id AND status = 'completed'
    )
    WHERE id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Grants
GRANT SELECT, INSERT, UPDATE ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;
