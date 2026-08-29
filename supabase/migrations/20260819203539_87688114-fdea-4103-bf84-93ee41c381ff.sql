
-- Grant EXECUTE on submit_task to authenticated users
-- This is required for users to be able to complete tasks and earn points.
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO authenticated;

-- Also ensure it's callable by service_role
GRANT EXECUTE ON FUNCTION public.submit_task(uuid, uuid) TO service_role;
