-- Automated Fraud Detection System

-- 1. Add fraud status and flags to redemptions
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS is_flagged boolean DEFAULT false;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS fraud_score float DEFAULT 0;
ALTER TABLE public.redemptions ADD COLUMN IF NOT EXISTS fraud_details jsonb DEFAULT '{}'::jsonb;

-- 2. Function to detect potential fraud on redemption request
CREATE OR REPLACE FUNCTION public.detect_redemption_fraud()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := NEW.user_id;
    v_fraud_flags text[] := ARRAY[]::text[];
    v_fraud_score float := 0;
    v_recent_redemptions_count int;
    v_total_points_24h int;
    v_points_balance int;
    v_user_created_at timestamp with time zone;
    v_is_flagged boolean := false;
BEGIN
    -- Only run check on new redemptions or when status is pending
    IF TG_OP = 'UPDATE' AND OLD.status <> 'pending' THEN
        RETURN NEW;
    END IF;

    -- A. Check for rapid-fire redemptions (more than 3 in 1 hour)
    SELECT count(*) INTO v_recent_redemptions_count
    FROM public.redemptions
    WHERE user_id = v_user_id
      AND created_at > now() - interval '1 hour';
    
    IF v_recent_redemptions_count >= 3 THEN
        v_fraud_flags := array_append(v_fraud_flags, 'high_frequency_redemption');
        v_fraud_score := v_fraud_score + 0.4;
    END IF;

    -- B. Check for high points earning in short period (e.g., > 1000 points in 24h)
    SELECT coalesce(sum(amount), 0) INTO v_total_points_24h
    FROM public.points_transactions
    WHERE user_id = v_user_id
      AND type = 'earn'
      AND created_at > now() - interval '24 hours';
    
    IF v_total_points_24h > 1000 THEN
        v_fraud_flags := array_append(v_fraud_flags, 'unusually_high_earnings_24h');
        v_fraud_score := v_fraud_score + 0.3;
    END IF;

    -- C. Check account age (flag if account is less than 24 hours old)
    SELECT created_at INTO v_user_created_at
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_user_created_at > now() - interval '24 hours' THEN
        v_fraud_flags := array_append(v_fraud_flags, 'new_account_payout');
        v_fraud_score := v_fraud_score + 0.2;
    END IF;

    -- D. Check for suspicious referral patterns (same IP/fingerprint logic would go here if we tracked it)
    -- For now, check if they have a large number of referrals but zero tasks completed
    IF EXISTS (
        SELECT 1 FROM public.referrals r
        WHERE r.referrer_id = v_user_id
        HAVING count(*) > 10
    ) AND NOT EXISTS (
        SELECT 1 FROM public.task_submissions ts
        WHERE ts.user_id = v_user_id
          AND ts.status = 'verified'
    ) THEN
        v_fraud_flags := array_append(v_fraud_flags, 'suspicious_referral_only_profile');
        v_fraud_score := v_fraud_score + 0.5;
    END IF;

    -- E. Auto-hold logic
    IF v_fraud_score >= 0.5 OR array_length(v_fraud_flags, 1) > 0 THEN
        v_is_flagged := true;
        NEW.status := 'review_required'; -- NEW STATUS: Holds the payout
        NEW.is_flagged := true;
        NEW.fraud_score := v_fraud_score;
        NEW.fraud_details := jsonb_build_object(
            'flags', v_fraud_flags,
            'checked_at', now(),
            'score', v_fraud_score
        );
        
        -- Log to audit
        INSERT INTO public.admin_audit_logs (action_type, target_table, target_id, new_data)
        VALUES ('auto_fraud_flag', 'redemptions', NEW.id, NEW.fraud_details);
    END IF;

    RETURN NEW;
END;
$$;

-- 3. Trigger for fraud detection
DROP TRIGGER IF EXISTS tr_detect_redemption_fraud ON public.redemptions;
CREATE TRIGGER tr_detect_redemption_fraud
BEFORE INSERT OR UPDATE ON public.redemptions
FOR EACH ROW
EXECUTE FUNCTION public.detect_redemption_fraud();

-- 4. Grant permissions
GRANT UPDATE(is_flagged, fraud_score, fraud_details) ON public.redemptions TO authenticated;
GRANT UPDATE(is_flagged, fraud_score, fraud_details) ON public.redemptions TO service_role;

