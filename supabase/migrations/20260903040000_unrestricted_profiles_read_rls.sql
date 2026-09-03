-- ==============================================================================
-- Master Resolution: Unrestricted Profile & Role Reads + Resync Point Balances
-- ==============================================================================

-- 1. PROFILES: Allow unrestricted SELECT for all authenticated users
-- (Ensures dashboard balances, leaderboards, admin users list, and avatars never fail)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can select their own and referee profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can select their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins and moderators can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Privileged roles can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Privileged roles can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Anyone authenticated can view basic profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;

-- Open SELECT policy: All authenticated and anon clients can read profiles
CREATE POLICY "Public profiles are viewable by everyone"
ON public.profiles
FOR SELECT
TO authenticated, anon
USING (true);

-- Secure UPDATE policy: Users update their own profile; Admins can update any profile
CREATE POLICY "Users and admins can update profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  auth.uid() = id 
  OR public.has_role(auth.uid(), 'admin')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
)
WITH CHECK (
  auth.uid() = id 
  OR public.has_role(auth.uid(), 'admin')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 2. USER ROLES: Allow authenticated SELECT
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can read own roles or admins read all" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can manage all roles" ON public.user_roles;
DROP POLICY IF EXISTS "Anyone authenticated can view user roles" ON public.user_roles;

CREATE POLICY "Anyone authenticated can view user roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Admins can manage all roles"
ON public.user_roles
FOR ALL
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 3. POINTS TRANSACTIONS: Allow users to read own transactions, admins read all
ALTER TABLE public.points_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own transactions" ON public.points_transactions;
DROP POLICY IF EXISTS "Admins can read all transactions" ON public.points_transactions;
DROP POLICY IF EXISTS "Users and admins can read transactions" ON public.points_transactions;

CREATE POLICY "Users and admins can read transactions"
ON public.points_transactions
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR public.has_role(auth.uid(), 'admin')
  OR public.has_role(auth.uid(), 'moderator')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 4. RESYNCHRONIZE POINT BALANCES
UPDATE public.profiles p
SET points_balance = GREATEST(0, COALESCE((
    SELECT SUM(pt.amount) 
    FROM public.points_transactions pt 
    WHERE pt.user_id = p.id 
      AND (pt.status IS NULL OR pt.status = 'completed')
), 0));

-- Grant broad API permissions
GRANT SELECT, UPDATE ON public.profiles TO authenticated, anon, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_roles TO authenticated, service_role;
GRANT SELECT, INSERT ON public.points_transactions TO authenticated, service_role;
