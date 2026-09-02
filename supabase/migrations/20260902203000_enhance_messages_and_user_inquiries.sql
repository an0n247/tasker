-- ==============================================================================
-- Migration: Enhance Messages System, User Support Inquiries, and Realtime Sync
-- ==============================================================================

-- 1. Ensure RLS policies on messages permit user-initiated support inquiries
DROP POLICY IF EXISTS "Users can insert support inquiries or replies" ON public.messages;
CREATE POLICY "Users can insert support inquiries or replies"
ON public.messages FOR INSERT
TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND (
        -- Either a new support inquiry (root message)
        (parent_id IS NULL AND is_broadcast = false)
        OR
        -- Or a reply to an allowed thread
        (
            parent_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.messages parent
                WHERE parent.id = messages.parent_id
                  AND parent.allow_replies = true
                  AND (parent.recipient_id = auth.uid() OR parent.sender_id = auth.uid() OR parent.is_broadcast = true)
            )
        )
    )
);

-- 2. Create RPC function for users to submit support inquiries / messages to Admin
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

    -- Ensure profile exists
    SELECT * INTO v_sender_profile FROM public.profiles WHERE id = v_user_id;

    -- Insert support message thread with sender = user, recipient = NULL (open to admin staff)
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

    -- Notify administrators
    INSERT INTO public.notifications (user_id, title, message, type, metadata)
    SELECT 
        ur.user_id,
        'New Support Message from @' || COALESCE(v_sender_profile.username, 'member'),
        SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
        'message',
        jsonb_build_object('message_id', v_message_id, 'sender_id', v_user_id)
    FROM public.user_roles ur
    WHERE ur.role IN ('admin', 'moderator');

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

-- 3. Robust send_message_reply function
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
    v_is_admin BOOLEAN := false;
    v_target_recipient_id UUID;
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

    WHILE v_parent.parent_id IS NOT NULL LOOP
        SELECT * INTO v_parent FROM public.messages WHERE id = v_parent.parent_id;
    END LOOP;

    v_is_admin := public.has_role(v_user_id, 'admin') OR public.has_role(v_user_id, 'moderator');

    IF NOT v_is_admin THEN
        IF NOT v_parent.allow_replies THEN
            RETURN jsonb_build_object('success', false, 'message', 'Replies are disabled for this message.');
        END IF;

        IF v_parent.recipient_id IS NOT NULL AND v_parent.recipient_id <> v_user_id AND v_parent.sender_id <> v_user_id THEN
            RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: You are not a participant in this conversation.');
        END IF;
    END IF;

    -- Determine target recipient for reply
    IF v_is_admin THEN
        IF v_parent.sender_id <> v_user_id THEN
            v_target_recipient_id := v_parent.sender_id;
        ELSE
            v_target_recipient_id := v_parent.recipient_id;
        END IF;
    ELSE
        IF v_parent.sender_id = v_user_id THEN
            v_target_recipient_id := v_parent.recipient_id;
        ELSE
            v_target_recipient_id := v_parent.sender_id;
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
        v_target_recipient_id,
        TRIM(p_body),
        v_parent.allow_replies,
        false,
        false,
        now(),
        now()
    )
    RETURNING id INTO v_reply_id;

    -- Update parent thread updated_at timestamp
    UPDATE public.messages SET updated_at = now() WHERE id = v_parent.id;

    SELECT * INTO v_sender_profile FROM public.profiles WHERE id = v_user_id;

    -- Send notifications
    IF NOT v_is_admin THEN
        -- User replied: notify the admins / message author
        IF v_parent.sender_id IS NOT NULL AND v_parent.sender_id <> v_user_id THEN
            INSERT INTO public.notifications (user_id, title, message, type, metadata)
            VALUES (
                v_parent.sender_id,
                'New Reply from @' || COALESCE(v_sender_profile.username, 'member'),
                SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
                'message',
                jsonb_build_object('message_id', v_parent.id, 'reply_id', v_reply_id)
            );
        ELSE
            INSERT INTO public.notifications (user_id, title, message, type, metadata)
            SELECT 
                ur.user_id,
                'New Reply from @' || COALESCE(v_sender_profile.username, 'member'),
                SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
                'message',
                jsonb_build_object('message_id', v_parent.id, 'reply_id', v_reply_id)
            FROM public.user_roles ur
            WHERE ur.role IN ('admin', 'moderator');
        END IF;
    ELSE
        -- Admin replied: notify recipient
        IF v_target_recipient_id IS NOT NULL THEN
            INSERT INTO public.notifications (user_id, title, message, type, metadata)
            VALUES (
                v_target_recipient_id,
                'New Reply from Administration ✉️',
                SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
                'message',
                jsonb_build_object('message_id', v_parent.id, 'reply_id', v_reply_id)
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true, 'reply_id', v_reply_id, 'message', 'Reply sent successfully');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 4. Grants
GRANT EXECUTE ON FUNCTION public.send_user_support_message(TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_message_reply(UUID, TEXT) TO authenticated, service_role;
