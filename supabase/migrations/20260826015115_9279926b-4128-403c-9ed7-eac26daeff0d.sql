CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_welcome_bonus integer := 50;
  v_referrer_id uuid;
  v_supplied_referral text;
  v_username text;
  v_referral_code text;
BEGIN
  SELECT COALESCE(
    CASE
      WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
      WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
      ELSE NULL
    END,
    50
  )
  INTO v_welcome_bonus
  FROM public.app_settings
  WHERE key IN ('welcome_bonus_amount_referee', 'welcome_bonus')
  ORDER BY CASE WHEN key = 'welcome_bonus_amount_referee' THEN 0 ELSE 1 END
  LIMIT 1;

  v_welcome_bonus := COALESCE(v_welcome_bonus, 50);
  v_username := NULLIF(btrim(new.raw_user_meta_data->>'username'), '');
  v_supplied_referral := NULLIF(btrim(COALESCE(
    new.raw_user_meta_data->>'referral_code_used',
    new.raw_user_meta_data->>'referral_code',
    new.raw_user_meta_data->>'referred_by'
  )), '');

  IF v_supplied_referral IS NOT NULL THEN
    SELECT p.id
    INTO v_referrer_id
    FROM public.profiles p
    WHERE p.id <> new.id
      AND (
        lower(p.referral_code) = lower(v_supplied_referral)
        OR lower(p.username) = lower(v_supplied_referral)
      )
    ORDER BY CASE WHEN lower(p.referral_code) = lower(v_supplied_referral) THEN 0 ELSE 1 END
    LIMIT 1;
  END IF;

  v_referral_code := COALESCE(
    v_username,
    lower(split_part(COALESCE(new.email, new.id::text), '@', 1))
  );

  INSERT INTO public.profiles (
    id, email, points_balance, username, full_name, referral_code, referred_by
  )
  VALUES (
    new.id,
    COALESCE(new.email, ''),
    v_welcome_bonus,
    v_username,
    NULLIF(btrim(new.raw_user_meta_data->>'full_name'), ''),
    v_referral_code,
    v_referrer_id
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      username = COALESCE(public.profiles.username, EXCLUDED.username),
      full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
      referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
      referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by);

  INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
  VALUES (new.id, v_welcome_bonus, 'bonus', 'Welcome bonus', 'completed', new.id)
  ON CONFLICT DO NOTHING;

  IF v_referrer_id IS NOT NULL THEN
    INSERT INTO public.referrals (referrer_id, referee_id)
    VALUES (v_referrer_id, new.id)
    ON CONFLICT (referee_id) DO UPDATE
    SET referrer_id = EXCLUDED.referrer_id;

    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    VALUES (
      v_referrer_id,
      'New Referral!',
      'Someone signed up using your referral. Your bonus unlocks after their first completed task.',
      'info',
      jsonb_build_object('referee_id', new.id)
    );
  END IF;

  RETURN new;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO postgres, service_role;

CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id uuid;
  v_referral_bonus integer := 75;
  v_referee_name text;
  v_transaction_id uuid;
BEGIN
  IF NEW.status = 'verified' AND OLD.status IS DISTINCT FROM 'verified' THEN
    SELECT r.referrer_id
    INTO v_referrer_id
    FROM public.referrals r
    WHERE r.referee_id = NEW.user_id;

    IF v_referrer_id IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

      SELECT COALESCE(
        CASE
          WHEN jsonb_typeof(value) = 'number' THEN (value #>> '{}')::integer
          WHEN jsonb_typeof(value) = 'object' THEN (value->>'amount')::integer
          ELSE NULL
        END,
        75
      )
      INTO v_referral_bonus
      FROM public.app_settings
      WHERE key IN ('welcome_bonus_amount_referrer', 'referral_bonus')
      ORDER BY CASE WHEN key = 'welcome_bonus_amount_referrer' THEN 0 ELSE 1 END
      LIMIT 1;

      v_referral_bonus := COALESCE(v_referral_bonus, 75);
      SELECT COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your friend')
      INTO v_referee_name
      FROM public.profiles p
      WHERE p.id = NEW.user_id;

      INSERT INTO public.points_transactions (
        user_id, amount, type, description, status, source_id
      )
      VALUES (
        v_referrer_id,
        v_referral_bonus,
        'referral',
        'Referral bonus: ' || COALESCE(v_referee_name, 'your friend') || ' completed their first task',
        'completed',
        NEW.user_id
      )
      ON CONFLICT DO NOTHING
      RETURNING id INTO v_transaction_id;

      IF v_transaction_id IS NOT NULL THEN
        INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
        VALUES (
          v_referrer_id,
          v_referral_bonus,
          'Referral bonus for ' || COALESCE(v_referee_name, 'referee') || '''s first task',
          'handle_referral_reward_on_first_task'
        );

        INSERT INTO public.notifications (
          user_id, title, message, type, transaction_id, metadata
        )
        VALUES (
          v_referrer_id,
          'Referral Reward!',
          'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_name, 'your friend') || ' completed their first task!',
          'referral',
          v_transaction_id,
          jsonb_build_object('referee_id', NEW.user_id, 'points', v_referral_bonus)
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_referral_reward_on_first_task() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_referral_reward_on_first_task() TO postgres, service_role;

DROP TRIGGER IF EXISTS on_task_verified_referral ON public.task_submissions;
DROP TRIGGER IF EXISTS tr_handle_referral_reward_on_first_task ON public.task_submissions;
CREATE TRIGGER on_task_verified_referral
AFTER UPDATE OF status ON public.task_submissions
FOR EACH ROW
WHEN (NEW.status = 'verified' AND OLD.status IS DISTINCT FROM 'verified')
EXECUTE FUNCTION public.handle_referral_reward_on_first_task();

WITH inferred_referrals AS (
  SELECT DISTINCT ON (u.id)
    u.id AS referee_id,
    ref.id AS referrer_id
  FROM auth.users u
  JOIN public.profiles ref
    ON ref.id <> u.id
   AND (
     lower(ref.referral_code) = lower(COALESCE(
       u.raw_user_meta_data->>'referral_code_used',
       u.raw_user_meta_data->>'referral_code',
       u.raw_user_meta_data->>'referred_by'
     ))
     OR lower(ref.username) = lower(COALESCE(
       u.raw_user_meta_data->>'referral_code_used',
       u.raw_user_meta_data->>'referral_code',
       u.raw_user_meta_data->>'referred_by'
     ))
   )
  WHERE NULLIF(btrim(COALESCE(
    u.raw_user_meta_data->>'referral_code_used',
    u.raw_user_meta_data->>'referral_code',
    u.raw_user_meta_data->>'referred_by'
  )), '') IS NOT NULL
  ORDER BY u.id,
    CASE WHEN lower(ref.referral_code) = lower(COALESCE(
      u.raw_user_meta_data->>'referral_code_used',
      u.raw_user_meta_data->>'referral_code',
      u.raw_user_meta_data->>'referred_by'
    )) THEN 0 ELSE 1 END
)
INSERT INTO public.referrals (referrer_id, referee_id)
SELECT referrer_id, referee_id
FROM inferred_referrals
ON CONFLICT (referee_id) DO UPDATE
SET referrer_id = EXCLUDED.referrer_id;

UPDATE public.profiles p
SET referred_by = r.referrer_id
FROM public.referrals r
WHERE r.referee_id = p.id
  AND p.referred_by IS DISTINCT FROM r.referrer_id;

WITH eligible AS (
  SELECT r.referrer_id, r.referee_id,
         COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your friend') AS referee_name
  FROM public.referrals r
  LEFT JOIN public.profiles p ON p.id = r.referee_id
  WHERE EXISTS (
    SELECT 1 FROM public.task_submissions ts
    WHERE ts.user_id = r.referee_id AND ts.status = 'verified'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.points_transactions pt
    WHERE pt.user_id = r.referrer_id
      AND (
        (pt.type IN ('referral', 'referral_bonus') AND pt.source_id = r.referee_id)
        OR (
          pt.type IN ('referral', 'referral_bonus')
          AND pt.source_id IS NULL
          AND pt.created_at <= r.created_at + interval '10 minutes'
          AND pt.created_at >= r.created_at - interval '10 minutes'
        )
      )
  )
), inserted_rewards AS (
  INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
  SELECT e.referrer_id, 75, 'referral',
         'Referral bonus: ' || e.referee_name || ' completed their first task',
         'completed', e.referee_id
  FROM eligible e
  ON CONFLICT DO NOTHING
  RETURNING user_id, amount, source_id, id
)
INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
SELECT ir.user_id,
       'Referral Reward!',
       'Your missing referral reward has been credited: ' || ir.amount || ' points.',
       'referral',
       ir.id,
       jsonb_build_object('referee_id', ir.source_id, 'points', ir.amount, 'repaired', true)
FROM inserted_rewards ir;

SELECT public.sync_points_balance(r.referrer_id)
FROM (SELECT DISTINCT referrer_id FROM public.referrals) r;