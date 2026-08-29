# Plan - Assign Admin Role

Assign the 'admin' role to `rolalekanhq@gmail.com` to grant access to the admin panel and management features.

## Proposed Changes

### Database
- Create a migration to insert the 'admin' role for user `3e18d6c9-1579-4673-812a-fcc6e43a428b` (rolalekanhq@gmail.com) into the `public.user_roles` table.
- Use an `UPSERT` pattern to ensure the operation is idempotent.

## Technical Details
- SQL: `INSERT INTO public.user_roles (user_id, role) VALUES ('3e18d6c9-1579-4673-812a-fcc6e43a428b', 'admin') ON CONFLICT (user_id, role) DO NOTHING;`
- This grants access to `src/routes/admin.tsx` which is protected by the `has_role(auth.uid(), 'admin')` policy.

## Verification Plan
- Run a query to confirm the role is present in `public.user_roles`.
- User can verify by logging in and checking if the "Admin Panel" link appears in the navigation.
