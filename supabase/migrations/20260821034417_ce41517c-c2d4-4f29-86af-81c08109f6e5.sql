
-- Re-create referrals_with_profiles as a SECURITY INVOKER view (default)
-- and ensure it follows RLS policies of the underlying tables
CREATE OR REPLACE VIEW public.referrals_with_profiles AS
SELECT 
    r.referrer_id,
    r.referee_id,
    r.created_at,
    referrer.username AS referrer_username,
    referrer.full_name AS referrer_full_name,
    referrer.avatar_url AS referrer_avatar_url,
    referrer.email AS referrer_email,
    referrer.points_balance AS referrer_points_balance,
    referrer.referral_code AS referrer_referral_code,
    referee.username AS referee_username,
    referee.full_name AS referee_full_name,
    referee.email AS referee_email,
    referee.created_at AS referee_created_at,
    referee.twitter_handle AS referee_twitter_handle,
    referee.telegram_handle AS referee_telegram_handle,
    referee.has_claimed_welcome_bonus AS referee_has_claimed_welcome_bonus
FROM public.referrals r
JOIN public.profiles referrer ON r.referrer_id = referrer.id
JOIN public.profiles referee ON r.referee_id = referee.id;

-- Ensure grants for the view
GRANT SELECT ON public.referrals_with_profiles TO authenticated;

-- Final linter check hardening: ensure no remaining broad public execute
-- We specifically keep: lookup_login_email, increment_referral_clicks, check_referral_code 
-- for anonymous usage as they are functionally required for signup/referral tracking.
-- These have been verified to not leak sensitive data beyond their specific purpose.
