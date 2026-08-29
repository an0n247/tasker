-- 1. Remove duplicate point credits (keep the earliest per user/type/source)
DELETE FROM public.points_transactions pt
USING (
  SELECT id, row_number() OVER (PARTITION BY user_id, type, source_id ORDER BY created_at, id) AS rn
  FROM public.points_transactions
  WHERE source_id IS NOT NULL
) d
WHERE pt.id = d.id AND d.rn > 1;

-- 2. Backfill source_id for task earnings so they can be de-duplicated
UPDATE public.points_transactions pt
SET source_id = ts.id
FROM public.task_submissions ts
JOIN public.tasks t ON t.id = ts.task_id
WHERE pt.source_id IS NULL
  AND pt.type = 'earn'
  AND pt.user_id = ts.user_id
  AND pt.description = 'Completed task: ' || t.title;

-- 3. Re-run dedupe after backfill
DELETE FROM public.points_transactions pt
USING (
  SELECT id, row_number() OVER (PARTITION BY user_id, type, source_id ORDER BY created_at, id) AS rn
  FROM public.points_transactions
  WHERE source_id IS NOT NULL
) d
WHERE pt.id = d.id AND d.rn > 1;

-- 4. Hard idempotency guarantee at the database level
CREATE UNIQUE INDEX IF NOT EXISTS points_transactions_unique_source
  ON public.points_transactions (user_id, type, source_id)
  WHERE source_id IS NOT NULL;

-- 5. Task reward: one credit per submission, ever
CREATE OR REPLACE FUNCTION public.update_points_balance_on_task_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'verified' AND NEW.status = 'verified') OR
       (TG_OP = 'INSERT' AND NEW.status = 'verified') THEN

        INSERT INTO public.points_transactions (user_id, amount, type, description, source_id)
        SELECT NEW.user_id, t.points, 'earn', 'Completed task: ' || t.title, NEW.id
        FROM public.tasks t
        WHERE t.id = NEW.task_id
          AND NOT EXISTS (
            SELECT 1 FROM public.points_transactions p
            WHERE p.user_id = NEW.user_id
              AND p.type = 'earn'
              AND (p.source_id = NEW.id OR p.description = 'Completed task: ' || t.title)
          )
        ON CONFLICT DO NOTHING;

    END IF;
    RETURN NEW;
END;
$function$;

-- 6. Referral reward: one credit per referee, ever
CREATE OR REPLACE FUNCTION public.handle_referral_reward_on_first_task()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_referrer_id UUID;
    v_referral_bonus INTEGER;
    v_referee_username TEXT;
    v_transaction_id UUID;
BEGIN
    IF NEW.status = 'approved' AND (OLD.status IS NULL OR OLD.status <> 'approved') THEN
        SELECT referrer_id INTO v_referrer_id
        FROM public.referrals
        WHERE referee_id = NEW.user_id;

        IF v_referrer_id IS NOT NULL THEN
            -- Serialize concurrent confirmations for this referrer/referee pair
            PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

            IF NOT EXISTS (
                SELECT 1 FROM public.points_transactions
                WHERE user_id = v_referrer_id
                  AND type IN ('referral', 'referral_bonus')
                  AND source_id = NEW.user_id
            ) THEN
                SELECT (value->>'amount')::integer INTO v_referral_bonus
                FROM public.app_settings WHERE key = 'referral_bonus';
                v_referral_bonus := COALESCE(v_referral_bonus, 75);

                SELECT username INTO v_referee_username FROM public.profiles WHERE id = NEW.user_id;

                INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
                VALUES (
                    v_referrer_id, v_referral_bonus, 'referral',
                    'Referral bonus for ' || COALESCE(v_referee_username, 'a new user') || ' completing their first task',
                    'completed', NEW.user_id
                )
                ON CONFLICT DO NOTHING
                RETURNING id INTO v_transaction_id;

                IF v_transaction_id IS NOT NULL THEN
                    INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
                    VALUES (v_referrer_id, v_referral_bonus, 'Referral bonus for ' || COALESCE(v_referee_username, 'referee') || ' first task', 'handle_referral_reward_on_first_task');

                    INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
                    VALUES (
                        v_referrer_id,
                        'Referral Reward Earned!',
                        'You earned ' || v_referral_bonus || ' points because ' || COALESCE(v_referee_username, 'your referral') || ' completed their first task!',
                        'reward', v_transaction_id, jsonb_build_object('referee_id', NEW.user_id)
                    );
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- 7. Signup referral rows: never duplicate
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 50;
    v_new_user_bonus INTEGER := 50;
BEGIN
    SELECT referrer_id INTO v_referrer_id FROM public.referrals WHERE referee_id = NEW.id;

    IF v_referrer_id IS NOT NULL THEN
        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (v_referrer_id, v_referral_reward_points, 'referral',
                'Referral bonus for ' || NEW.username || ' (Pending profile completion)', 'pending', NEW.id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (NEW.id, v_new_user_bonus, 'welcome_bonus',
                'Welcome bonus (Pending profile completion)', 'pending', v_referrer_id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.notifications (user_id, title, message, type)
        VALUES (v_referrer_id, 'Referral Pending!',
                'You have a pending reward for referring ' || NEW.username || '. It will be available once they complete their profile.',
                'info');
    END IF;

    RETURN NEW;
END;
$function$;

-- 8. Resync balances after the cleanup
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.profiles LOOP
    PERFORM public.sync_points_balance(r.id);
  END LOOP;
END $$;