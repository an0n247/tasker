-- Standardize global referral statistics in a view
DROP VIEW IF EXISTS public.global_referral_stats;
CREATE VIEW public.global_referral_stats WITH (security_invoker = true) AS
SELECT 
    COUNT(*) as total_referrals,
    COUNT(DISTINCT referrer_id) as total_referrers,
    COUNT(*) FILTER (WHERE p.has_claimed_welcome_bonus = true) as completed_referrals
FROM public.referrals r
JOIN public.profiles p ON r.referee_id = p.id;

GRANT SELECT ON public.global_referral_stats TO authenticated;
GRANT SELECT ON public.global_referral_stats TO service_role;
