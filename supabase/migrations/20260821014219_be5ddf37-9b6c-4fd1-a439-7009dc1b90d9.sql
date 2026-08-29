-- Create Rank View
CREATE OR REPLACE VIEW public.user_ranks AS
SELECT 
    p.id as user_id,
    p.username,
    COALESCE(r.referral_count, 0) as referral_count,
    CASE 
        WHEN COALESCE(r.referral_count, 0) >= 50 THEN 'Legend'
        WHEN COALESCE(r.referral_count, 0) >= 20 THEN 'Pro'
        WHEN COALESCE(r.referral_count, 0) >= 10 THEN 'Super Referrer'
        WHEN COALESCE(r.referral_count, 0) >= 5 THEN 'Elite'
        ELSE 'Novice'
    END as rank_name,
    CASE 
        WHEN COALESCE(r.referral_count, 0) >= 50 THEN 5
        WHEN COALESCE(r.referral_count, 0) >= 20 THEN 4
        WHEN COALESCE(r.referral_count, 0) >= 10 THEN 3
        WHEN COALESCE(r.referral_count, 0) >= 5 THEN 2
        ELSE 1
    END as rank_level
FROM public.profiles p
LEFT JOIN (
    SELECT referrer_id, COUNT(*) as referral_count
    FROM public.referrals
    GROUP BY referrer_id
) r ON p.id = r.referrer_id;

GRANT SELECT ON public.user_ranks TO authenticated;
GRANT SELECT ON public.user_ranks TO service_role;

-- Create Detailed Referrals View
CREATE OR REPLACE VIEW public.my_referrals_detailed AS
SELECT 
    r.referrer_id,
    p.id as referee_id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.created_at as joined_at,
    CASE WHEN p.has_claimed_welcome_bonus THEN 'Active' ELSE 'Pending Profile' END as status
FROM public.referrals r
JOIN public.profiles p ON r.referee_id = p.id;

GRANT SELECT ON public.my_referrals_detailed TO authenticated;
GRANT SELECT ON public.my_referrals_detailed TO service_role;