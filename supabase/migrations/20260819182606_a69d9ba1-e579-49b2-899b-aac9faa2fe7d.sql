
-- 1. Create task_submissions table to track user progress
CREATE TABLE IF NOT EXISTS public.task_submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    task_id uuid REFERENCES public.tasks(id) ON DELETE CASCADE NOT NULL,
    status text NOT NULL CHECK (status IN ('pending', 'verified', 'rejected')),
    created_at timestamp with time zone DEFAULT now(),
    UNIQUE (user_id, task_id)
);

-- 2. Add verification fields to tasks
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS link_url text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS verification_required boolean DEFAULT false;

-- 3. Grant access
GRANT SELECT, INSERT, UPDATE ON public.task_submissions TO authenticated;
GRANT ALL ON public.task_submissions TO service_role;

-- 4. Enable RLS
ALTER TABLE public.task_submissions ENABLE ROW LEVEL SECURITY;

-- 5. Create policies
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can view their own submissions' AND tablename = 'task_submissions'
    ) THEN
        CREATE POLICY "Users can view their own submissions"
        ON public.task_submissions FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'Users can create their own submissions' AND tablename = 'task_submissions'
    ) THEN
        CREATE POLICY "Users can create their own submissions"
        ON public.task_submissions FOR INSERT
        TO authenticated
        WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- 6. Create submit_task function with idempotency and rate limiting
CREATE OR REPLACE FUNCTION public.submit_task(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_existing_submission record;
    v_points integer;
    v_now timestamp with time zone := now();
    v_last_submission timestamp with time zone;
BEGIN
    -- SECURITY CHECK: Ensure the authenticated user is only submitting for themselves
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized: You can only submit tasks for your own account.');
    END IF;

    -- RATE LIMITING: Prevent spamming submissions (max 1 every 2 seconds per user)
    SELECT created_at INTO v_last_submission
    FROM public.task_submissions
    WHERE user_id = _user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_submission IS NOT NULL AND v_now - v_last_submission < interval '2 seconds' THEN
        RETURN json_build_object('success', false, 'message', 'Please wait a moment before submitting again.');
    END IF;

    -- Use explicit lock to prevent concurrent submissions for the same user/task
    PERFORM pg_advisory_xact_lock(hashtext(_user_id::text || _task_id::text));

    -- 1. Get task details
    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Task not found or inactive.');
    END IF;

    -- 2. Check for existing submission (IDEMPOTENCY)
    SELECT * INTO v_existing_submission FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id;
    
    IF FOUND THEN
        IF v_existing_submission.status = 'verified' THEN
            RETURN json_build_object('success', false, 'message', 'Task already completed and verified.');
        ELSIF v_existing_submission.status = 'pending' THEN
            RETURN json_build_object('success', false, 'message', 'Task submission is already under review.');
        END IF;
        RETURN json_build_object('success', false, 'message', 'Task has already been submitted (Status: ' || v_existing_submission.status || ').');
    END IF;

    -- 3. Create submission
    IF v_task_record.verification_required THEN
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'pending', v_now);
        
        RETURN json_build_object('success', true, 'message', 'Task submitted for verification.');
    ELSE
        -- Auto-verify and award points
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now);
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed task: ' || v_task_record.title, v_now);
        
        RETURN json_build_object('success', true, 'message', 'Task completed! ' || v_task_record.points || ' points awarded.', 'points', v_task_record.points);
    END IF;
END;
$$;
