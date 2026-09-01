-- ==============================================================================
-- Migration: Admin-to-User Messages & Inbox System
-- ==============================================================================

-- 1. Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    recipient_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT,
    body TEXT NOT NULL,
    allow_replies BOOLEAN DEFAULT true NOT NULL,
    is_broadcast BOOLEAN DEFAULT false NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Indexes for performant lookups
CREATE INDEX IF NOT EXISTS idx_messages_parent_id ON public.messages(parent_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON public.messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_is_broadcast ON public.messages(is_broadcast);

-- 2. Create message_reads table to track read status for broadcast announcements per user
CREATE TABLE IF NOT EXISTS public.message_reads (
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    read_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reads_user_id ON public.message_reads(user_id);

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for messages

-- SELECT: Admins can see all messages. Users can see messages directed to them, broadcasts, or threads they are part of.
DROP POLICY IF EXISTS "Admins have full access to messages" ON public.messages;
CREATE POLICY "Admins have full access to messages"
ON public.messages FOR ALL
TO authenticated
USING (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
)
WITH CHECK (
    public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'moderator')
);

DROP POLICY IF EXISTS "Users can read their own messages and broadcasts" ON public.messages;
CREATE POLICY "Users can read their own messages and broadcasts"
ON public.messages FOR SELECT
TO authenticated
USING (
    recipient_id = auth.uid()
    OR sender_id = auth.uid()
    OR is_broadcast = true
    OR (
        parent_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.messages parent
            WHERE parent.id = messages.parent_id
              AND (parent.recipient_id = auth.uid() OR parent.sender_id = auth.uid() OR parent.is_broadcast = true)
        )
    )
);

-- INSERT: Users can only insert replies to a thread where they are the recipient and allow_replies is true
DROP POLICY IF EXISTS "Users can reply to threads with allowed replies" ON public.messages;
CREATE POLICY "Users can reply to threads with allowed replies"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND parent_id IS NOT NULL
    AND EXISTS (
        SELECT 1 FROM public.messages parent
        WHERE parent.id = messages.parent_id
          AND parent.allow_replies = true
          AND (parent.recipient_id = auth.uid() OR parent.is_broadcast = true)
    )
);

-- UPDATE: Users can update is_read status on their own direct messages
DROP POLICY IF EXISTS "Users can update read status on their received messages" ON public.messages;
CREATE POLICY "Users can update read status on their received messages"
ON public.messages FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

-- RLS Policies for message_reads
DROP POLICY IF EXISTS "Users can view and insert their own message reads" ON public.message_reads;
CREATE POLICY "Users can view and insert their own message reads"
ON public.message_reads FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 4. Secure RPC function for Admin to send messages / broadcasts
CREATE OR REPLACE FUNCTION public.send_admin_message(
    p_recipient_id UUID,
    p_subject TEXT,
    p_body TEXT,
    p_allow_replies BOOLEAN DEFAULT true,
    p_is_broadcast BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_message_id UUID;
    v_recipient_name TEXT;
BEGIN
    IF v_admin_id IS NULL OR NOT (public.has_role(v_admin_id, 'admin') OR public.has_role(v_admin_id, 'moderator')) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin or Moderator role required');
    END IF;

    IF p_body IS NULL OR TRIM(p_body) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Message body cannot be empty');
    END IF;

    IF NOT p_is_broadcast AND p_recipient_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Recipient is required for direct messages');
    END IF;

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
        v_admin_id,
        CASE WHEN p_is_broadcast THEN NULL ELSE p_recipient_id END,
        NULLIF(TRIM(p_subject), ''),
        TRIM(p_body),
        COALESCE(p_allow_replies, true),
        COALESCE(p_is_broadcast, false),
        false,
        now(),
        now()
    )
    RETURNING id INTO v_message_id;

    -- Send in-app notification
    IF p_is_broadcast THEN
        -- Notify all users
        INSERT INTO public.notifications (user_id, title, message, type, metadata)
        SELECT 
            p.id,
            COALESCE(NULLIF(TRIM(p_subject), ''), 'Platform Announcement 📢'),
            SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
            'system',
            jsonb_build_object('message_id', v_message_id, 'is_broadcast', true)
        FROM public.profiles p;
    ELSE
        -- Notify specific recipient
        INSERT INTO public.notifications (user_id, title, message, type, metadata)
        VALUES (
            p_recipient_id,
            COALESCE(NULLIF(TRIM(p_subject), ''), 'New Message from Administration ✉️'),
            SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
            'message',
            jsonb_build_object('message_id', v_message_id)
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'message_id', v_message_id, 
        'message', 'Message sent successfully'
    );
END;
$$;

-- 5. Secure RPC function for User or Admin to reply to a thread
CREATE OR REPLACE FUNCTION public.send_message_reply(
    p_parent_id UUID,
    p_body TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_parent public.messages%ROWTYPE;
    v_reply_id UUID;
    v_is_admin BOOLEAN;
    v_sender_profile public.profiles%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    IF p_body IS NULL OR TRIM(p_body) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Reply cannot be empty');
    END IF;

    -- Fetch root parent thread
    SELECT * INTO v_parent FROM public.messages WHERE id = p_parent_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Conversation thread not found');
    END IF;

    -- Ensure parent is top-level root
    WHILE v_parent.parent_id IS NOT NULL LOOP
        SELECT * INTO v_parent FROM public.messages WHERE id = v_parent.parent_id;
    END LOOP;

    v_is_admin := public.has_role(v_user_id, 'admin') OR public.has_role(v_user_id, 'moderator');

    -- If sender is a regular user, check if replies are allowed and user is part of the thread
    IF NOT v_is_admin THEN
        IF NOT v_parent.allow_replies THEN
            RETURN jsonb_build_object('success', false, 'message', 'Replies are disabled for this message.');
        END IF;

        IF v_parent.recipient_id IS NOT NULL AND v_parent.recipient_id <> v_user_id THEN
            RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: You are not a participant in this conversation.');
        END IF;
    END IF;

    -- Insert reply
    INSERT INTO public.messages (
        parent_id,
        sender_id,
        recipient_id,
        body,
        allow_replies,
        is_broadcast,
        is_read,
        created_at,
        updated_at
    )
    VALUES (
        v_parent.id,
        v_user_id,
        CASE WHEN v_is_admin THEN v_parent.recipient_id ELSE v_parent.sender_id END,
        TRIM(p_body),
        v_parent.allow_replies,
        false,
        false,
        now(),
        now()
    )
    RETURNING id INTO v_reply_id;

    -- Update thread timestamp
    UPDATE public.messages SET updated_at = now() WHERE id = v_parent.id;

    SELECT * INTO v_sender_profile FROM public.profiles WHERE id = v_user_id;

    -- If user replied, notify the admin/sender
    IF NOT v_is_admin THEN
        INSERT INTO public.notifications (user_id, title, message, type, metadata)
        VALUES (
            v_parent.sender_id,
            'New Reply from ' || COALESCE(v_sender_profile.username, 'a user'),
            SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
            'message',
            jsonb_build_object('message_id', v_parent.id, 'reply_id', v_reply_id)
        );
    ELSE
        -- If admin replied, notify the user
        IF v_parent.recipient_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, message, type, metadata)
            VALUES (
                v_parent.recipient_id,
                'New Reply from Support/Admin',
                SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
                'message',
                jsonb_build_object('message_id', v_parent.id, 'reply_id', v_reply_id)
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'reply_id', v_reply_id, 'message', 'Reply sent successfully');
END;
$$;

-- 6. RPC function to mark message or thread as read
CREATE OR REPLACE FUNCTION public.mark_message_read(p_message_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_msg public.messages%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    SELECT * INTO v_msg FROM public.messages WHERE id = p_message_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Message not found');
    END IF;

    IF v_msg.is_broadcast THEN
        INSERT INTO public.message_reads (message_id, user_id, read_at)
        VALUES (p_message_id, v_user_id, now())
        ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = now();
    ELSE
        UPDATE public.messages
        SET is_read = true, read_at = now()
        WHERE (id = p_message_id OR parent_id = p_message_id)
          AND recipient_id = v_user_id
          AND is_read = false;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 7. RPC function to get unread message count for badge
CREATE OR REPLACE FUNCTION public.get_unread_message_count()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_direct_unread INTEGER := 0;
    v_broadcast_unread INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN 0;
    END IF;

    -- Direct messages and replies directed to user
    SELECT COUNT(*) INTO v_direct_unread
    FROM public.messages m
    WHERE m.recipient_id = v_user_id
      AND m.is_read = false;

    -- Unread broadcast root messages
    SELECT COUNT(*) INTO v_broadcast_unread
    FROM public.messages m
    WHERE m.is_broadcast = true
      AND m.parent_id IS NULL
      AND NOT EXISTS (
          SELECT 1 FROM public.message_reads mr
          WHERE mr.message_id = m.id AND mr.user_id = v_user_id
      );

    RETURN COALESCE(v_direct_unread, 0) + COALESCE(v_broadcast_unread, 0);
END;
$$;

-- 8. Grant permissions
GRANT ALL ON public.messages TO authenticated, service_role;
GRANT ALL ON public.message_reads TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_admin_message(UUID, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_message_reply(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_message_read(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_unread_message_count() TO authenticated, service_role;
