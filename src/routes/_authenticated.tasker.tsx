import { createFileRoute, redirect } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { AdminPanel } from "@/components/AdminPanel";
import { AccessDenied } from "@/components/admin/AccessDenied";
import { useQuery } from "@tanstack/react-query";

export const Route = createFileRoute("/_authenticated/tasker")({
  loader: async ({ location }) => {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      throw redirect({
        to: "/auth",
        search: { redirect: location.pathname },
      });
    }

    return { userId: user.id };
  },
  component: TaskerRouteComponent,
});

function TaskerRouteComponent() {
  const { userId } = Route.useLoaderData();

  const { data: roles, isLoading } = useQuery({
    queryKey: ["tasker-role-check", userId],
    queryFn: async () => {
      const [{ data: isAdmin }, { data: isModerator }, { data: isTasker }] = await Promise.all([
        supabase.rpc("has_role", { _user_id: userId, _role: "admin" as any }),
        supabase.rpc("has_role", { _user_id: userId, _role: "moderator" as any }),
        supabase.rpc("has_role", { _user_id: userId, _role: "tasker" as any }),
      ]);
      return { isAdmin, isModerator, isTasker };
    },
  });

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-accent/5">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      </div>
    );
  }

  const isAuthorized = roles?.isAdmin || roles?.isModerator || roles?.isTasker;

  if (!isAuthorized) {
    return (
      <div className="min-h-screen bg-accent/5">
        <AccessDenied />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-accent/5 pb-12">
      <div className="max-w-7xl mx-auto px-4 py-8 space-y-6">
        <div className="flex flex-col gap-2">
          <h1 className="text-4xl font-black tracking-tight text-foreground uppercase">
            Tasker Panel
          </h1>
          <p className="text-muted-foreground font-medium">
            Manage platform tasks and submissions.
          </p>
        </div>
        <AdminPanel />
      </div>
    </div>
  );
}
