-- ==============================================================================
-- Migration: Fix has_role function, messages table RLS, and admin permissions
-- ==============================================================================

-- 1. Upgrade public.has_role to check both user_roles and profiles.is_admin
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role public.app_role)
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

  -- 1. Check user_roles table
  IF EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  ) THEN
    RETURN true;
  END IF;

  -- 2. Check profiles table for is_admin flag
  IF _role = 'admin' AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = _user_id AND is_admin = true
  ) THEN
    RETURN true;
  END IF;

  -- 3. If checking for moderator and user is admin, return true
  IF _role = 'moderator' AND (
    EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'admin')
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id AND is_admin = true)
  ) THEN
    RETURN true;
  END IF;

  -- 4. If checking for tasker and user is admin or moderator
  IF _role = 'tasker' AND (
    EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('admin', 'moderator', 'tasker', 'task_manager'))
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = _user_id AND is_admin = true)
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- 2. Ensure olalekanhq@yahoo.com has admin in both user_roles and profiles
DO $$
DECLARE
  v_admin_uid UUID;
BEGIN
  SELECT id INTO v_admin_uid FROM auth.users WHERE email = 'olalekanhq@yahoo.com';
  IF v_admin_uid IS NOT NULL THEN
    UPDATE public.profiles SET is_admin = true WHERE id = v_admin_uid;
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_admin_uid, 'admin')
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
END $$;

-- 3. Ensure RLS policies on public.messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins have full access to messages" ON public.messages;
CREATE POLICY "Admins have full access to messages"
ON public.messages FOR ALL
TO authenticated
USING (
    public.has_role(auth.uid(), 'admin') 
    OR public.has_role(auth.uid(), 'moderator')
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
)
WITH CHECK (
    public.has_role(auth.uid(), 'admin') 
    OR public.has_role(auth.uid(), 'moderator')
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true)
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

DROP POLICY IF EXISTS "Users can update read status on their received messages" ON public.messages;
CREATE POLICY "Users can update read status on their received messages"
ON public.messages FOR UPDATE
TO authenticated
USING (recipient_id = auth.uid())
WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS "Users can view and insert their own message reads" ON public.message_reads;
CREATE POLICY "Users can view and insert their own message reads"
ON public.message_reads FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 4. Re-harden send_admin_message function
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
    v_is_auth_admin BOOLEAN := false;
BEGIN
    IF v_admin_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    v_is_auth_admin := public.has_role(v_admin_id, 'admin') 
      OR public.has_role(v_admin_id, 'moderator')
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = v_admin_id AND is_admin = true);

    IF NOT v_is_auth_admin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin role required');
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

    IF p_is_broadcast THEN
        INSERT INTO public.notifications (user_id, title, message, type, metadata)
        SELECT 
            p.id,
            COALESCE(NULLIF(TRIM(p_subject), ''), 'Platform Announcement 📢'),
            SUBSTRING(TRIM(p_body) FROM 1 FOR 120),
            'system',
            jsonb_build_object('message_id', v_message_id, 'is_broadcast', true)
        FROM public.profiles p;
    ELSE
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

-- 5. Re-harden send_message_reply function
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
    v_sender_profile public.profiles%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    IF p_body IS NULL OR TRIM(p_body) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Reply cannot be empty');
    END IF;

    SELECT * INTO v_parent FROM public.messages WHERE id = p_parent_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Conversation thread not found');
    END IF;

    WHILE v_parent.parent_id IS NOT NULL LOOP
        SELECT * INTO v_parent FROM public.messages WHERE id = v_parent.parent_id;
    END LOOP;

    v_is_admin := public.has_role(v_user_id, 'admin') 
      OR public.has_role(v_user_id, 'moderator')
      OR EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id AND is_admin = true);

    IF NOT v_is_admin THEN
        IF NOT v_parent.allow_replies THEN
            RETURN jsonb_build_object('success', false, 'message', 'Replies are disabled for this message.');
        END IF;

        IF v_parent.recipient_id IS NOT NULL AND v_parent.recipient_id <> v_user_id AND v_parent.sender_id <> v_user_id THEN
            RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: You are not a participant in this conversation.');
        END IF;
    END IF;

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

    UPDATE public.messages SET updated_at = now() WHERE id = v_parent.id;
    SELECT * INTO v_sender_profile FROM public.profiles WHERE id = v_user_id;

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

GRANT ALL ON public.messages TO authenticated, service_role;
GRANT ALL ON public.message_reads TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.send_admin_message(UUID, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_message_reply(UUID, TEXT) TO authenticated, service_role;
