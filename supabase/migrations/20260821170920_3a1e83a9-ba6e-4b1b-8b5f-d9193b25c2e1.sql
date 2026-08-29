CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_bonus INTEGER;
    v_referee_username TEXT;
    v_transaction_id UUID;
BEGIN
    IF (NEW.status = 'verified' AND (OLD.status IS NULL OR OLD.status != 'verified')) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.task_submissions 
            WHERE user_id = NEW.user_id 
            AND status = 'verified' 
            AND id != NEW.id
        ) THEN
            SELECT referred_by, username INTO v_referrer_id, v_referee_username 
            FROM public.profiles 
            WHERE id = NEW.user_id;

            IF v_referrer_id IS NOT NULL THEN
                SELECT (value->>0)::integer INTO v_referral_bonus 
                FROM public.app_settings 
                WHERE key = 'welcome_bonus_amount_referrer';
                
                v_referral_bonus := COALESCE(v_referral_bonus, 75);

                INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
                VALUES (
                    v_referrer_id,
                    v_referral_bonus,
                    'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed',
                    NEW.user_id
                ) RETURNING id INTO v_transaction_id;

                -- AUDIT LOG
                INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

                INSERT INTO public.notifications (user_id, title, message, type, transaction_id)
                VALUES (
                    v_referrer_id,
                    'Referral Reward Earned!',
                    'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                    'reward',
                    v_transaction_id
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;