-- Re-create views with explicit security_invoker=true to satisfy linter and ensure RLS is respected.
-- In Supabase/Postgres 15+, we can use security_invoker = true.

DROP VIEW IF EXISTS public.leaderboard;
CREATE VIEW public.leaderboard WITH (security_invoker = true) AS
SELECT id,
    full_name,
    username,
    avatar_url,
    points_balance,
    rank() OVER (ORDER BY points_balance DESC) AS rank
   FROM profiles p
  ORDER BY points_balance DESC
 LIMIT 100;
GRANT SELECT ON public.leaderboard TO authenticated;
GRANT SELECT ON public.leaderboard TO anon;

DROP VIEW IF EXISTS public.referrals_with_profiles;
CREATE VIEW public.referrals_with_profiles WITH (security_invoker = true) AS
SELECT r.referrer_id,
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
   FROM ((referrals r
     JOIN profiles referrer ON ((r.referrer_id = referrer.id)))
     JOIN profiles referee ON ((r.referee_id = referee.id)));
GRANT SELECT ON public.referrals_with_profiles TO authenticated;

DROP VIEW IF EXISTS public.user_ranks;
CREATE VIEW public.user_ranks WITH (security_invoker = true) AS
SELECT p.id AS user_id,
    p.username,
    COALESCE(r.referral_count, (0)::bigint) AS referral_count,
        CASE
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 50) THEN 'Legend'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 20) THEN 'Pro'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 10) THEN 'Super Referrer'::text
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 5) THEN 'Elite'::text
            ELSE 'Novice'::text
        END AS rank_name,
        CASE
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 50) THEN 5
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 20) THEN 4
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 10) THEN 3
            WHEN (COALESCE(r.referral_count, (0)::bigint) >= 5) THEN 2
            ELSE 1
        END AS rank_level
   FROM (profiles p
     LEFT JOIN ( SELECT referrals.referrer_id,
            count(*) AS referral_count
           FROM referrals
          GROUP BY referrals.referrer_id) r ON ((p.id = r.referrer_id)));
GRANT SELECT ON public.user_ranks TO authenticated;

DROP VIEW IF EXISTS public.my_referrals_detailed;
CREATE VIEW public.my_referrals_detailed WITH (security_invoker = true) AS
SELECT r.referrer_id,
    p.id AS referee_id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.created_at AS joined_at,
        CASE
            WHEN p.has_claimed_welcome_bonus THEN 'Active'::text
            ELSE 'Pending Profile'::text
        END AS status
   FROM (referrals r
     JOIN profiles p ON ((r.referee_id = p.id)));
GRANT SELECT ON public.my_referrals_detailed TO authenticated;
