-- Create analytics_events table
CREATE TABLE public.analytics_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    event_name TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Grant access
GRANT INSERT, SELECT ON public.analytics_events TO anon;
GRANT INSERT, SELECT ON public.analytics_events TO authenticated;
GRANT ALL ON public.analytics_events TO service_role;

-- Enable RLS
ALTER TABLE public.analytics_events ENABLE ROW LEVEL SECURITY;

-- Allow anonymous and authenticated users to insert events
CREATE POLICY "Allow anyone to insert events" ON public.analytics_events FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow users to view their own events" ON public.analytics_events FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);
