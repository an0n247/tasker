
-- Create a view to simplify searching across referrals and profiles
CREATE OR REPLACE VIEW public.referrals_with_profiles AS
SELECT 
    r.*,
    referrer.username as referrer_username,
    referrer.full_name as referrer_full_name,
    referrer.avatar_url as referrer_avatar_url,
    referrer.email as referrer_email,
    referrer.points_balance as referrer_points_balance,
    referrer.referral_code as referrer_referral_code,
    referee.username as referee_username,
    referee.full_name as referee_full_name,
    referee.email as referee_email,
    referee.created_at as referee_created_at,
    referee.twitter_handle as referee_twitter_handle,
    referee.telegram_handle as referee_telegram_handle,
    referee.has_claimed_welcome_bonus as referee_has_claimed_welcome_bonus
FROM public.referrals r
JOIN public.profiles referrer ON r.referrer_id = referrer.id
JOIN public.profiles referee ON r.referee_id = referee.id;

GRANT SELECT ON public.referrals_with_profiles TO authenticated;
GRANT ALL ON public.referrals_with_profiles TO service_role;
