-- Migration: Restrict broad SELECT policies on profiles, task_submissions, and tasks to admin and moderator roles only.
-- Prevents non-privileged roles (like 'tasker') from reading all users' private data or global submissions.

-- 1. PROFILES TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins and moderators can select all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Privileged roles can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can read their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can select their own profile" ON public.profiles;

-- Normal users can only read their own profile or profiles of users who signed up using their referral link
CREATE POLICY "Users can select their own and referee profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  auth.uid() = id 
  OR EXISTS (
    SELECT 1 FROM public.referrals r 
    WHERE r.referrer_id = auth.uid() AND r.referee_id = public.profiles.id
  )
);

-- Only admin and moderator roles can select all profiles
CREATE POLICY "Admins and moderators can select all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);


-- 2. TASK_SUBMISSIONS TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can view all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Privileged roles can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Admins and moderators can view all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Admins and moderators can select all submissions" ON public.task_submissions;
DROP POLICY IF EXISTS "Users can view their own submissions" ON public.task_submissions;

-- Normal users can only view their own submissions
CREATE POLICY "Users can view their own submissions"
ON public.task_submissions
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Only admin and moderator roles can view all user submissions
CREATE POLICY "Admins and moderators can select all submissions"
ON public.task_submissions
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);


-- 3. TASKS TABLE:
-- Drop any broad or privileged select policies
DROP POLICY IF EXISTS "Privileged roles can select all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Privileged roles can view all tasks" ON public.tasks;
DROP POLICY IF EXISTS "Privileged roles can manage tasks" ON public.tasks;
DROP POLICY IF EXISTS "Anyone can read active tasks" ON public.tasks;
DROP POLICY IF EXISTS "Admins and moderators can select all tasks" ON public.tasks;

-- All authenticated users can read active tasks to earn
CREATE POLICY "Anyone can read active tasks"
ON public.tasks
FOR SELECT
TO authenticated
USING (is_active = TRUE);

-- Only admins and moderators can select all tasks (including inactive / drafts)
CREATE POLICY "Admins and moderators can select all tasks"
ON public.tasks
FOR SELECT
TO authenticated
USING (
  public.has_role(auth.uid(), 'admin') OR 
  public.has_role(auth.uid(), 'moderator')
);
