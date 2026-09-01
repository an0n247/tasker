-- ==============================================================================
-- Migration: Bulletproof Messages System, Roles, and Admin History Delivery
-- ==============================================================================

-- 1. Ensure public.app_role enum exists with all roles
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
    CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'tasker', 'task_manager', 'user');
  ELSE
    ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'admin';
    ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'moderator';
    ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'tasker';
    ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'task_manager';
    ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'user';
  END IF;
END $$;

-- 2. Ensure user_roles table exists
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL DEFAULT 'user',
    UNIQUE (user_id, role)
);

GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own roles or admins read all" ON public.user_roles;
CREATE POLICY "Users can read own roles or admins read all"
ON public.user_roles FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM auth.users u
    WHERE u.id = auth.uid() AND LOWER(u.email) IN ('olalekanhq@yahoo.com')
  )
  OR EXISTS (
    SELECT 1 FROM public.user_roles ur
    WHERE ur.user_id = auth.uid() AND ur.role = 'admin'
  )
);

-- 3. Robust has_role function
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

  -- 1. Direct email bypass for system admin
  IF EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = _user_id AND LOWER(email) IN ('olalekanhq@yahoo.com')
  ) THEN
    RETURN true;
  END IF;

  -- 2. Check user_roles table for exact role
  IF EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  ) THEN
    RETURN true;
  END IF;

  -- 3. Admins inherit moderator, tasker, task_manager roles
  IF _role IN ('moderator', 'tasker', 'task_manager') AND EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'admin'
  ) THEN
    RETURN true;
  END IF;

  -- 4. Moderators inherit tasker role
  IF _role = 'tasker' AND EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = 'moderator'
  ) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

-- 4. Ensure admin role is assigned in user_roles for olalekanhq@yahoo.com
DO $$
DECLARE
  v_admin_rec RECORD;
BEGIN
  FOR v_admin_rec IN SELECT id FROM auth.users WHERE LOWER(email) = 'olalekanhq@yahoo.com' LOOP
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_admin_rec.id, 'admin')
    ON CONFLICT (user_id, role) DO UPDATE SET role = 'admin';
  END LOOP;
END $$;

-- 5. Ensure messages and message_reads tables exist
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

CREATE INDEX IF NOT EXISTS idx_messages_parent_id ON public.messages(parent_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient_id ON public.messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_is_broadcast ON public.messages(is_broadcast);

CREATE TABLE IF NOT EXISTS public.message_reads (
    message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    read_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reads_user_id ON public.message_reads(user_id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reads ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies on messages
DROP POLICY IF EXISTS "Admins have full access to messages" ON public.messages;
CREATE POLICY "Admins have full access to messages"
ON public.messages FOR ALL
TO authenticated
USING (
    public.has_role(auth.uid(), 'admin') 
    OR public.has_role(auth.uid(), 'moderator')
)
WITH CHECK (
    public.has_role(auth.uid(), 'admin') 
    OR public.has_role(auth.uid(), 'moderator')
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

-- 7. High-Reliability send_admin_message RPC
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
    v_admin_email TEXT;
BEGIN
    IF v_admin_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated. Please log in.');
    END IF;

    -- Verify authorization
    v_is_auth_admin := public.has_role(v_admin_id, 'admin') 
                    OR public.has_role(v_admin_id, 'moderator');

    IF NOT v_is_auth_admin THEN
        RETURN jsonb_build_object('success', false, 'message', 'Unauthorized: Admin or Moderator role required');
    END IF;

    IF p_body IS NULL OR TRIM(p_body) = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Message body cannot be empty');
    END IF;

    IF NOT p_is_broadcast AND p_recipient_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Please select a recipient user');
    END IF;

    -- Ensure admin profile exists in public.profiles so foreign key constraint passes
    SELECT email INTO v_admin_email FROM auth.users WHERE id = v_admin_id;
    INSERT INTO public.profiles (id, email, username, full_name)
    VALUES (v_admin_id, COALESCE(v_admin_email, 'admin@noblegain.com'), 'Admin', 'Administration')
    ON CONFLICT (id) DO NOTHING;

    -- Insert message
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

    -- Insert Notification(s)
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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM
    );
END;
$$;

-- 8. High-Reliability send_message_reply RPC
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

    v_is_admin := public.has_role(v_user_id, 'admin') OR public.has_role(v_user_id, 'moderator');

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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- 9. Mark Message Read RPC
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
        RETURN jsonb_build_object('success', false);
    END IF;

    SELECT * INTO v_msg FROM public.messages WHERE id = p_message_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false);
    END IF;

    IF v_msg.is_broadcast THEN
        INSERT INTO public.message_reads (message_id, user_id, read_at)
        VALUES (p_message_id, v_user_id, now())
        ON CONFLICT (message_id, user_id) DO UPDATE SET read_at = now();
    ELSE
        IF v_msg.recipient_id = v_user_id THEN
            UPDATE public.messages
            SET is_read = true, read_at = now()
            WHERE id = p_message_id;
        END IF;
    END IF;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 10. Grants
GRANT ALL ON public.messages TO authenticated, service_role;
GRANT ALL ON public.message_reads TO authenticated, service_role;
GRANT ALL ON public.user_roles TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_role(UUID, public.app_role) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.send_admin_message(UUID, TEXT, TEXT, BOOLEAN, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.send_message_reply(UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.mark_message_read(UUID) TO authenticated, service_role;
