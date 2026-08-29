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

  const { data: role, isLoading: isRoleLoading } = useQuery({
    queryKey: ["userRole", session?.user?.id],
    queryFn: async () => {
      if (!session?.user?.id) return "user" as UserRole;

      const { data, error } = await supabase
        .from("user_roles")
        .select("role")
        .eq("user_id", session.user.id)
        .limit(1)
        .maybeSingle();

      if (error) {
        console.error("Error fetching role:", error);
        return "user" as UserRole;
      }

      return (data?.role as UserRole) || "user";
    },
    enabled: !!session?.user?.id,
  });

  return {
    user: session?.user ?? null,
    role: role ?? "user",
    isAdmin: role === "admin",
    isModerator: role === "moderator" || role === "admin",
    isTasker:
      role === "tasker" || role === "task_manager" || role === "moderator" || role === "admin",
    isLoading: isSessionLoading || (!!session?.user?.id && isRoleLoading),
  };
}
