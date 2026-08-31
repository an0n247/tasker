INSERT INTO public.user_roles (user_id, role)
SELECT '3e18d6c9-1579-4673-812a-fcc6e43a428b'::uuid, 'admin'::public.app_role
WHERE EXISTS (SELECT 1 FROM auth.users WHERE id = '3e18d6c9-1579-4673-812a-fcc6e43a428b')
ON CONFLICT (user_id, role) DO NOTHING;