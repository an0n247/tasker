-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  avatar_url TEXT,
  points_balance INTEGER DEFAULT 0 NOT NULL,
  referral_code TEXT UNIQUE,
  referred_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own profile" ON public.profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Create tasks table
CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  points INTEGER NOT NULL,
  category TEXT, -- e.g., 'daily', 'social', 'survey'
  icon_name TEXT,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.tasks TO authenticated;
GRANT ALL ON public.tasks TO service_role;

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active tasks" ON public.tasks
  FOR SELECT TO authenticated USING (is_active = TRUE);

-- Create points_transactions table
CREATE TABLE public.points_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL, -- 'earn', 'spend'
  description TEXT,
  source_id UUID, -- reference to task_id or redemption_id
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.points_transactions TO authenticated;
GRANT ALL ON public.points_transactions TO service_role;

ALTER TABLE public.points_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own transactions" ON public.points_transactions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Create rewards table
CREATE TABLE public.rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  cost_points INTEGER NOT NULL,
  image_url TEXT,
  stock_count INTEGER,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT ON public.rewards TO authenticated;
GRANT ALL ON public.rewards TO service_role;

ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read active rewards" ON public.rewards
  FOR SELECT TO authenticated USING (is_active = TRUE);

-- Create redemptions table
CREATE TABLE public.redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_id UUID NOT NULL REFERENCES public.rewards(id),
  status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'approved', 'rejected'
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

GRANT SELECT, INSERT ON public.redemptions TO authenticated;
GRANT ALL ON public.redemptions TO service_role;

ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own redemptions" ON public.redemptions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can insert redemptions" ON public.redemptions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, referral_code)
  VALUES (
    new.id,
    new.email,
    encode(gen_random_bytes(6), 'hex')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
