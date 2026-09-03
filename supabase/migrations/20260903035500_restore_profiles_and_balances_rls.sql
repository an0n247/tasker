-- ==============================================================================
-- Master Fix & Recovery Migration:
-- 1. Restore complete, bulletproof RLS on public.profiles (Users can read own + admins read all)
-- 2. Restore complete RLS on public.user_roles and public.points_transactions
-- 3. Resynchronize all user points balances from points_transactions
-- ==============================================================================

-- 1. PROFILES RLS POLICIES
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop all conflicting or broken policies on profiles
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

-- Policy 1: Every authenticated user can always read their own profile (Critical for dashboard balance!)
CREATE POLICY "Users can read their own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Policy 2: Admins, moderators, and system admin email can view ALL profiles
CREATE POLICY "Admins and moderators can select all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') 
  OR public.has_role(auth.uid(), 'moderator')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
  OR EXISTS (
    SELECT 1 FROM auth.users u 
    WHERE u.id = auth.uid() AND LOWER(u.email) IN ('olalekanhq@yahoo.com')
  )
);

-- Policy 3: Users can update their own profile
CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy 4: Admins can update all profiles
CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 2. USER_ROLES RLS POLICIES
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own roles" ON public.user_roles;
DROP POLICY IF EXISTS "Users can read own roles or admins read all" ON public.user_roles;
DROP POLICY IF EXISTS "Admins can manage all roles" ON public.user_roles;

CREATE POLICY "Users can read their own roles"
ON public.user_roles
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR public.has_role(auth.uid(), 'admin')
  OR public.has_role(auth.uid(), 'moderator')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);

CREATE POLICY "Admins can manage all roles"
ON public.user_roles
FOR ALL
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 3. POINTS_TRANSACTIONS RLS POLICIES
ALTER TABLE public.points_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own transactions" ON public.points_transactions;
DROP POLICY IF EXISTS "Admins can read all transactions" ON public.points_transactions;

CREATE POLICY "Users can read their own transactions"
ON public.points_transactions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Admins can read all transactions"
ON public.points_transactions
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin')
  OR public.has_role(auth.uid(), 'moderator')
  OR LOWER(COALESCE(auth.jwt() ->> 'email', '')) IN ('olalekanhq@yahoo.com')
);


-- 4. RESYNCHRONIZE AND RESTORE ALL POINTS BALANCES
-- Recalculates points_balance for each profile from their transactions
UPDATE public.profiles p
SET points_balance = GREATEST(0, COALESCE((
    SELECT SUM(pt.amount) 
    FROM public.points_transactions pt 
    WHERE pt.user_id = p.id 
      AND (pt.status IS NULL OR pt.status = 'completed')
), 0));

-- Grant broad permissions so API roles can read correctly
GRANT SELECT, UPDATE ON public.profiles TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_roles TO authenticated, service_role;
GRANT SELECT, INSERT ON public.points_transactions TO authenticated, service_role;
