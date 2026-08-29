-- 1. User Roles System
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('admin', 'user');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    from public.user_roles
    where user_id = _user_id
      and role = _role
  )
$$;

-- 2. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- 'points', 'referral', 'redemption', 'streak'
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, UPDATE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can read their own notifications') THEN
        CREATE POLICY "Users can read their own notifications" ON public.notifications
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Users can update their own notifications') THEN
        CREATE POLICY "Users can update their own notifications" ON public.notifications
            FOR UPDATE TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

-- 3. Streaks Table
CREATE TABLE IF NOT EXISTS public.user_streaks (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak INTEGER DEFAULT 0 NOT NULL,
    last_activity_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    longest_streak INTEGER DEFAULT 0 NOT NULL
);

GRANT SELECT ON public.user_streaks TO authenticated;
GRANT ALL ON public.user_streaks TO service_role;

ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_streaks' AND policyname = 'Users can read their own streak') THEN
        CREATE POLICY "Users can read their own streak" ON public.user_streaks
            FOR SELECT TO authenticated USING (auth.uid() = user_id);
    END IF;
END $$;

-- 4. Admin Policies (Example for rewards)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'rewards' AND policyname = 'Admins can manage rewards') THEN
        CREATE POLICY "Admins can manage rewards" ON public.rewards
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'redemptions' AND policyname = 'Admins can manage redemptions') THEN
        CREATE POLICY "Admins can manage redemptions" ON public.redemptions
            FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin'));
    END IF;
END $$;

-- 5. Trigger for Notifications on points_transactions
CREATE OR REPLACE FUNCTION public.notify_on_points_transaction()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, title, message, type)
    VALUES (
        NEW.user_id,
        CASE WHEN NEW.amount > 0 THEN 'Points Earned!' ELSE 'Points Spent' END,
        NEW.description,
        'points'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_points_transaction ON public.points_transactions;
CREATE TRIGGER on_points_transaction
    AFTER INSERT ON public.points_transactions
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_points_transaction();
