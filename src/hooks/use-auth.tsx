import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useEffect, useState } from "react";

export type UserRole = "admin" | "moderator" | "tasker" | "task_manager" | "user";

export function useAuth() {
  const [session, setSession] = useState<any>(null);
  const [isSessionLoading, setIsSessionLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setIsSessionLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setIsSessionLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const { data: authRoles, isLoading: isRoleLoading } = useQuery({
    queryKey: ["userRole", session?.user?.id],
    queryFn: async () => {
      if (!session?.user?.id)
        return { role: "user" as UserRole, isAdmin: false, isModerator: false, isTasker: false };

      const [{ data: userRoleData }, { data: isAdminRpc }, { data: isModRpc }] =
        await Promise.all([
          supabase
            .from("user_roles")
            .select("role")
            .eq("user_id", session.user.id)
            .limit(1)
            .maybeSingle(),
          supabase.rpc("has_role", { _user_id: session.user.id, _role: "admin" }),
          supabase.rpc("has_role", { _user_id: session.user.id, _role: "moderator" }),
        ]);

      const isAdmin = Boolean(userRoleData?.role === "admin" || isAdminRpc);
      const isModerator = Boolean(isAdmin || userRoleData?.role === "moderator" || isModRpc);
      const role = isAdmin
        ? ("admin" as UserRole)
        : isModerator
          ? ("moderator" as UserRole)
          : ((userRoleData?.role as UserRole) || "user");

      return {
        role,
        isAdmin,
        isModerator,
        isTasker: isModerator || role === "tasker" || role === "task_manager",
      };
    },
    enabled: !!session?.user?.id,
  });

  return {
    user: session?.user ?? null,
    role: authRoles?.role ?? "user",
    isAdmin: authRoles?.isAdmin ?? false,
    isModerator: authRoles?.isModerator ?? false,
    isTasker: authRoles?.isTasker ?? false,
    isLoading: isSessionLoading || (!!session?.user?.id && isRoleLoading),
  };
}
