
-- Grant EXECUTE on the has_role function to authenticated users
-- This is necessary for the app to check user roles in the frontend and routes.
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;

-- Also ensure it's callable by service_role for any backend work
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO service_role;
