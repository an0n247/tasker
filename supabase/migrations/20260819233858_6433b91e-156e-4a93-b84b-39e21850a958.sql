CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS TRIGGER AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75; -- Points awarded to the referrer
    v_referee_reward_points INTEGER := 75;  -- Points awarded to the referee
BEGIN
    -- Find the referrer from the referrals table
    SELECT referrer_id INTO v_referrer_id
    FROM public.referrals
    WHERE referee_id = NEW.id;

    -- If a referrer was found, award both parties
    IF v_referrer_id IS NOT NULL THEN
        -- Award Referrer
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            v_referrer_id,
            v_referral_reward_points,
            'referral',
            'Referral bonus for ' || NEW.username
        );
        
        -- Award Referee (Welcome Bonus)
        INSERT INTO public.points_transactions (user_id, amount, type, description)
        VALUES (
            NEW.id,
            v_referee_reward_points,
            'welcome_bonus',
            'Welcome bonus for joining via referral'
        );
        
        -- Notify the referrer
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notifications') THEN
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                v_referrer_id,
                'Referral Reward!',
                'You earned ' || v_referral_reward_points || ' points because ' || NEW.username || ' joined using your code.',
                'reward'
            );
            
            -- Notify the referee
            INSERT INTO public.notifications (user_id, title, message, type)
            VALUES (
                NEW.id,
                'Welcome Bonus!',
                'You earned ' || v_referee_reward_points || ' points as a welcome bonus for joining via referral.',
                'reward'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
