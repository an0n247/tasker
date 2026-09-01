-- Assign admin role and permissions to olalekanhq@yahoo.com

DO $$
DECLARE
  target_user_id uuid;
BEGIN
  -- Find the user's ID from auth.users or profiles
  SELECT id INTO target_user_id
  FROM auth.users
  WHERE lower(email) = 'olalekanhq@yahoo.com'
  LIMIT 1;

  IF target_user_id IS NOT NULL THEN
    -- Ensure admin role exists in public.user_roles
    INSERT INTO public.user_roles (user_id, role)
    VALUES (target_user_id, 'admin'::public.app_role)
    ON CONFLICT (user_id, role) DO NOTHING;

    -- Also update public.profiles is_admin flag if present
    UPDATE public.profiles
    SET is_admin = TRUE
    WHERE id = target_user_id OR lower(email) = 'olalekanhq@yahoo.com';

    RAISE NOTICE 'Admin role assigned to olalekanhq@yahoo.com (ID: %)', target_user_id;
  ELSE
    -- If user is only in profiles
    UPDATE public.profiles
    SET is_admin = TRUE
    WHERE lower(email) = 'olalekanhq@yahoo.com';

    RAISE NOTICE 'User not found in auth.users yet, updated profiles table.';
  END IF;
END $$;
