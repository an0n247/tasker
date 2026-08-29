
-- 1. Add video_ad_count to tasks table
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS video_ad_count INTEGER DEFAULT 0;

-- 2. Create a new table to track progress on video ad tasks
CREATE TABLE IF NOT EXISTS public.video_ad_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    watch_count INTEGER NOT NULL DEFAULT 0,
    last_watch_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, task_id)
);

-- 3. Enable RLS and add policies for video_ad_progress
ALTER TABLE public.video_ad_progress ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE ON public.video_ad_progress TO authenticated;
GRANT ALL ON public.video_ad_progress TO service_role;

CREATE POLICY "Users can view their own video progress"
    ON public.video_ad_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own video progress"
    ON public.video_ad_progress FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own watch count"
    ON public.video_ad_progress FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- 4. Create an RPC to record a video watch
CREATE OR REPLACE FUNCTION public.record_video_watch(_user_id uuid, _task_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_task_record record;
    v_progress_record record;
    v_now timestamp with time zone := now();
BEGIN
    -- SECURITY CHECK
    IF auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    -- 1. Get task details
    SELECT * INTO v_task_record FROM public.tasks WHERE id = _task_id AND is_active = true AND category = 'Videos';
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Video task not found or inactive.');
    END IF;

    -- 2. Check if already completed in task_submissions
    IF EXISTS (SELECT 1 FROM public.task_submissions WHERE user_id = _user_id AND task_id = _task_id AND status = 'verified') THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed.');
    END IF;

    -- 3. Update or insert progress
    INSERT INTO public.video_ad_progress (user_id, task_id, watch_count, last_watch_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET 
        watch_count = video_ad_progress.watch_count + 1,
        last_watch_at = v_now
    RETURNING * INTO v_progress_record;

    -- 4. Check if finished (10 ads)
    IF v_progress_record.watch_count >= v_task_record.video_ad_count THEN
        -- Auto-verify and award points
        INSERT INTO public.task_submissions (user_id, task_id, status, created_at)
        VALUES (_user_id, _task_id, 'verified', v_now)
        ON CONFLICT DO NOTHING;
        
        -- Award points
        INSERT INTO public.points_transactions (user_id, amount, type, description, created_at)
        VALUES (_user_id, v_task_record.points, 'earn', 'Completed video task: ' || v_task_record.title, v_now);
        
        RETURN json_build_object(
            'success', true, 
            'completed', true, 
            'watch_count', v_progress_record.watch_count,
            'points', v_task_record.points,
            'message', 'Goal reached! ' || v_task_record.points || ' points awarded.'
        );
    END IF;

    RETURN json_build_object(
        'success', true, 
        'completed', false, 
        'watch_count', v_progress_record.watch_count,
        'message', 'Video watch recorded (' || v_progress_record.watch_count || '/' || v_task_record.video_ad_count || ')'
    );
END;
$$;
