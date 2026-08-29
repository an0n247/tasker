ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS vast_tag_url TEXT;

COMMENT ON COLUMN public.tasks.vast_tag_url IS 'The VAST XML URL for video ad tasks';