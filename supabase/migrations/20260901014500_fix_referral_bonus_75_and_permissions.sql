-- ==============================================================================
-- Migration: Fix Referral Bonus (75 PTS) and Role Permissions for Messages Tab
-- ==============================================================================

-- 1. Ensure app_settings has 75 PTS for referrer and 50 PTS for referee
INSERT INTO public.app_settings (key, value, description)
VALUES 
  ('referral_bonus', '75'::jsonb, 'Referral bonus points awarded to the referrer'),
  ('welcome_bonus_amount_referrer', '75'::jsonb, 'Referral bonus awarded to referrer for invites'),
  ('welcome_bonus_amount_referee', '50'::jsonb, 'Welcome bonus awarded to referee / new user'),
  ('welcome_bonus', '50'::jsonb, 'Default welcome bonus awarded on signup')
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value;

-- 2. Update role_permissions to ensure 'messages' tab is enabled for admin, moderator, and task_manager
INSERT INTO public.role_permissions (role, tab_name, is_enabled)
VALUES 
  ('admin', 'messages', true),
  ('admin', 'analytics', true),
  ('admin', 'users', true),
  ('admin', 'tasks', true),
  ('admin', 'approvals', true),
  ('admin', 'rewards', true),
  ('admin', 'redemptions', true),
  ('admin', 'audit', true),
  ('admin', 'settings', true),
  ('moderator', 'messages', true),
  ('moderator', 'approvals', true),
  ('moderator', 'users', true),
  ('moderator', 'tasks', true)
ON CONFLICT (role, tab_name) DO UPDATE
SET is_enabled = true;

-- 3. Redefine handle_referral_reward_on_first_task with explicit 75 PTS
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
  v_is_new_verified boolean;
BEGIN
  v_is_new_verified := (TG_OP = 'INSERT' AND NEW.status = 'verified')
    OR (TG_OP = 'UPDATE' AND NEW.status = 'verified' AND (OLD.status IS NULL OR OLD.status <> 'verified'));

  IF v_is_new_verified THEN
    SELECT r.referrer_id INTO v_referrer_id 
    FROM public.referrals r 
    WHERE r.referee_id = NEW.user_id;

    IF v_referrer_id IS NOT NULL THEN
      PERFORM pg_advisory_xact_lock(hashtext(v_referrer_id::text || NEW.user_id::text));

      -- Reward only once per referee
      IF NOT EXISTS (
        SELECT 1 FROM public.points_transactions
        WHERE user_id = v_referrer_id AND type IN ('referral', 'referral_bonus') AND source_id = NEW.user_id
      ) THEN
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

        SELECT COALESCE(NULLIF(p.username, ''), NULLIF(p.full_name, ''), 'your referral')
        INTO v_referee_name FROM public.profiles p WHERE p.id = NEW.user_id;

        INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
        VALUES (
          v_referrer_id, 
          v_referral_bonus, 
          'referral',
          'Referral bonus: ' || COALESCE(v_referee_name, 'your referral') || ' completed their first task',
          'completed', 
          NEW.user_id
        )
        RETURNING id INTO v_transaction_id;

        IF v_transaction_id IS NOT NULL THEN
          -- Sync referrer balance immediately
          PERFORM public.sync_points_balance(v_referrer_id);

          INSERT INTO public.points_audit_logs (user_id, amount, reason, trigger_name)
          VALUES (
            v_referrer_id, 
            v_referral_bonus, 
            'Referral bonus for ' || COALESCE(v_referee_name, 'referee') || '''s first task',
            'handle_referral_reward_on_first_task'
          );

          INSERT INTO public.notifications (user_id, title, message, type, transaction_id, metadata)
          VALUES (
            v_referrer_id,
            'Referral Reward Earned! 🎉',
            'You earned +' || v_referral_bonus || ' PTS because ' || COALESCE(v_referee_name, 'your referral') || ' completed their first task!',
            'reward',
            v_transaction_id,
            jsonb_build_object('referee_id', NEW.user_id, 'points', v_referral_bonus)
          );
        END IF;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 4. Redefine reward_referrer_on_signup if called on profile/referral registration
CREATE OR REPLACE FUNCTION public.reward_referrer_on_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referrer_id UUID;
    v_referral_reward_points INTEGER := 75;
    v_new_user_bonus INTEGER := 50;
BEGIN
    SELECT referrer_id INTO v_referrer_id FROM public.referrals WHERE referee_id = NEW.id;

    IF v_referrer_id IS NOT NULL THEN
        -- Check if already awarded
        IF NOT EXISTS (
            SELECT 1 FROM public.points_transactions
            WHERE user_id = v_referrer_id AND type IN ('referral', 'referral_bonus') AND source_id = NEW.id
        ) THEN
            INSERT INTO public.points_transactions (user_id, amount, type, description, status, source_id)
            VALUES (
                v_referrer_id, 
                v_referral_reward_points, 
                'referral',
                'Referral bonus for ' || COALESCE(NEW.username, 'new member'), 
                'completed', 
                NEW.id
            )
            ON CONFLICT DO NOTHING;

            PERFORM public.sync_points_balance(v_referrer_id);

            INSERT INTO public.notifications (user_id, title, message, type, metadata)
            VALUES (
                v_referrer_id,
                'Referral Bonus Earned! 🎉',
                'You earned +' || v_referral_reward_points || ' PTS for referring @' || COALESCE(NEW.username, 'a friend') || '!',
                'reward',
                jsonb_build_object('referee_id', NEW.id, 'points', v_referral_reward_points)
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- 5. Upgrade any existing 50-point referral bonus transactions to 75 points and resync
DO $$
DECLARE
  r record;
BEGIN
  -- Find referral bonus transactions that were credited with 50 instead of 75
  FOR r IN 
    SELECT id, user_id, amount 
    FROM public.points_transactions 
    WHERE type IN ('referral', 'referral_bonus') 
      AND amount = 50
  LOOP
    UPDATE public.points_transactions 
    SET amount = 75 
    WHERE id = r.id;

    PERFORM public.sync_points_balance(r.user_id);
  END LOOP;
END $$;
