-- Ensure the Ads Link RPC is available after deployments that did not refresh
-- PostgREST's schema cache for the original feature migration.
CREATE TABLE IF NOT EXISTS public.ads_link_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    click_count INTEGER NOT NULL DEFAULT 0,
    last_click_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, task_id)
);

ALTER TABLE public.ads_link_progress ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.ads_link_progress TO authenticated;
GRANT ALL ON public.ads_link_progress TO service_role;

DROP POLICY IF EXISTS "Users can view their own ads link progress" ON public.ads_link_progress;
CREATE POLICY "Users can view their own ads link progress"
    ON public.ads_link_progress FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.record_ads_link_click(_user_id UUID, _task_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_progress RECORD;
    v_required_clicks INTEGER := 10;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF auth.uid() IS NULL OR auth.uid() <> _user_id THEN
        RETURN json_build_object('success', false, 'message', 'Unauthorized');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.tasks
        WHERE id = _task_id
          AND is_active = true
          AND category = 'Ads Link'
          AND NULLIF(TRIM(link_url), '') IS NOT NULL
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Ads Link task not found or inactive');
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.task_submissions
        WHERE user_id = _user_id
          AND task_id = _task_id
          AND status IN ('verified', 'approved')
    ) THEN
        RETURN json_build_object('success', false, 'message', 'Task already completed');
    END IF;

    INSERT INTO public.ads_link_progress (user_id, task_id, click_count, last_click_at)
    VALUES (_user_id, _task_id, 1, v_now)
    ON CONFLICT (user_id, task_id) DO UPDATE
    SET click_count = ads_link_progress.click_count + 1,
        last_click_at = v_now
    RETURNING * INTO v_progress;

    RETURN json_build_object(
        'success', true,
        'ready_to_claim', v_progress.click_count >= v_required_clicks,
        'click_count', v_progress.click_count,
        'required_clicks', v_required_clicks,
        'message', CASE
            WHEN v_progress.click_count >= v_required_clicks
                THEN 'All ten ad clicks recorded. You can now claim your reward.'
            ELSE format('Ad click recorded (%s/%s)', v_progress.click_count, v_required_clicks)
        END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_ads_link_click(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_ads_link_click(UUID, UUID) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
