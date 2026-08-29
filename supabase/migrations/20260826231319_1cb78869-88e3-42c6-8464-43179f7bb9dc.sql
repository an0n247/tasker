CREATE OR REPLACE FUNCTION public._restore_exec(sql text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$ BEGIN EXECUTE sql; END; $$;
REVOKE ALL ON FUNCTION public._restore_exec(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._restore_exec(text) TO sandbox_exec;