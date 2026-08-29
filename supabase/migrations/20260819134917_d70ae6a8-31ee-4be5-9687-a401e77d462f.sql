INSERT INTO public.user_roles (user_id, role) 
VALUES ('3e18d6c9-1579-4673-812a-fcc6e43a428b', 'admin') 
ON CONFLICT (user_id, role) DO NOTHING;