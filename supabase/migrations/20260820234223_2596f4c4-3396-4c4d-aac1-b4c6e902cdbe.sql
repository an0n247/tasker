INSERT INTO public.user_roles (user_id, role)
SELECT 'b687073f-357b-4490-868f-6e7d567b3da1'::uuid, 'moderator'::public.app_role
WHERE EXISTS (SELECT 1 FROM auth.users WHERE id = 'b687073f-357b-4490-868f-6e7d567b3da1')
ON CONFLICT (user_id, role) DO NOTHING;