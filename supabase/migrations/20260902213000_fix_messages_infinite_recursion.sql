-- ==============================================================================
-- Migration: Fix Infinite Recursion in Messages RLS Policies
-- ==============================================================================

-- 1. Helper function that runs as SECURITY DEFINER to avoid RLS recursion
CREATE OR REPLACE FUNCTION public.can_user_access_message(
    _sender_id UUID,
    _recipient_id UUID,
    _is_broadcast BOOLEAN,
    _parent_id UUID,
    _user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF _user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Admins/moderators can access all messages
    IF public.has_role(_user_id, 'admin') OR public.has_role(_user_id, 'moderator') THEN
        RETURN true;
    END IF;

    -- Direct participant or broadcast message
    IF _recipient_id = _user_id OR _sender_id = _user_id OR _is_broadcast = true THEN
        RETURN true;
    END IF;

    -- If this is a reply, check the root parent message without recursive RLS trigger
    IF _parent_id IS NOT NULL THEN
        RETURN EXISTS (
            SELECT 1 FROM public.messages p
            WHERE p.id = _parent_id
              AND (p.recipient_id = _user_id OR p.sender_id = _user_id OR p.is_broadcast = true)
        );
    END IF;

    RETURN false;
END;
$$;

-- 2. Helper function for insert/reply validation (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.can_user_reply_message(
    _sender_id UUID,
    _parent_id UUID,
    _user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF _user_id IS NULL OR _sender_id <> _user_id THEN
        RETURN false;
    END IF;

    -- Admins/moderators can insert any message
    IF public.has_role(_user_id, 'admin') OR public.has_role(_user_id, 'moderator') THEN
        RETURN true;
    END IF;

    -- If creating a root support message (parent_id IS NULL)
    IF _parent_id IS NULL THEN
        RETURN true;
    END IF;

    -- If replying to a thread, check if parent exists and allows replies without recursive RLS trigger
    RETURN EXISTS (
        SELECT 1 FROM public.messages p
        WHERE p.id = _parent_id
          AND p.allow_replies = true
          AND (p.recipient_id = _user_id OR p.sender_id = _user_id OR p.is_broadcast = true)
    );
END;
$$;

-- 3. Drop all previous recursive policies on messages
DROP POLICY IF EXISTS "Admins have full access to messages" ON public.messages;
DROP POLICY IF EXISTS "Users can read their own messages and broadcasts" ON public.messages;
DROP POLICY IF EXISTS "Users can reply to threads with allowed replies" ON public.messages;
DROP POLICY IF EXISTS "Users can insert support inquiries or replies" ON public.messages;
DROP POLICY IF EXISTS "Users can update read status on their received messages" ON public.messages;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_update_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_delete_policy" ON public.messages;

-- 4. Apply clean non-recursive policies on messages
CREATE POLICY "messages_select_policy"
ON public.messages FOR SELECT
TO authenticated
USING (
    public.can_user_access_message(sender_id, recipient_id, is_broadcast, parent_id, auth.uid())
);

CREATE POLICY "messages_insert_policy"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    public.can_user_reply_message(sender_id, parent_id, auth.uid())
);

CREATE POLICY "messages_update_policy"
ON public.messages FOR UPDATE
TO authenticated
USING (
    recipient_id = auth.uid()
    OR public.has_role(auth.uid(), 'admin')
    OR public.has_role(auth.uid(), 'moderator')
)
WITH CHECK (
    recipient_id = auth.uid()
    OR public.has_role(auth.uid(), 'admin')
    OR public.has_role(auth.uid(), 'moderator')
);

CREATE POLICY "messages_delete_policy"
ON public.messages FOR DELETE
TO authenticated
USING (
    public.has_role(auth.uid(), 'admin')
    OR public.has_role(auth.uid(), 'moderator')
);

-- 5. Message Reads policies
DROP POLICY IF EXISTS "Users can view and insert their own message reads" ON public.message_reads;
DROP POLICY IF EXISTS "message_reads_policy" ON public.message_reads;
CREATE POLICY "message_reads_policy"
ON public.message_reads FOR ALL
TO authenticated
USING (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'))
WITH CHECK (user_id = auth.uid() OR public.has_role(auth.uid(), 'admin'));

-- 6. RPC functions for support tickets and replies
CREATE OR REPLACE FUNCTION public.send_user_support_message(
    p_subject TEXT,
    p_body TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_message_id UUID;
    v_sender_profile public.profiles%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated. Please log in.');
    END IF;

    IF p_body IS NULL OR TRIM(p_body) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Message body cannot be empty.');
    END IF;

    SELECT * INTO v_sender_profile FROM public.profiles WHERE id = v_user_id;

    INSERT INTO public.messages (
        sender_id,
        recipient_id,
        subject,
        body,
        allow_replies,
        is_broadcast,
        is_read,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        NULL,
        COALESCE(NULLIF(TRIM(p_subject), ''), 'Member Support Inquiry'),
        TRIM(p_body),
        true,
        false,
        false,
        now(),
        now()
    )
    RETURNING id INTO v_message_id;

    -- Notify admins
    BEGIN
        INSERT INTO public.notifications (user_id, title, message, type, metadata)
        SELECT 
            ur.user_id,
            'New Support Message from @' || COALESCE(v_sender_profile.username, 'member'),
            SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
            'message',
            jsonb_build_object('message_id', v_message_id, 'sender_id', v_user_id)
        FROM public.user_roles ur
        WHERE ur.role IN ('admin', 'moderator');
    EXCEPTION WHEN OTHERS THEN
        -- Ignore notification failure if table differs
    END;

    RETURN jsonb_build_object(
        'success', true, 
        'message_id', v_message_id, 
        'message', 'Your message has been received by the support team.'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false, 
        'message', SQLERRM
    );
END;
$$;

-- 7. Grant Permissions
GRANT ALL ON public.messages TO authenticated, service_role;
GRANT ALL ON public.message_reads TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_user_access_message(UUID, UUID, BOOLEAN, UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_user_reply_message(UUID, UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_user_support_message(TEXT, TEXT) TO authenticated, service_role;
