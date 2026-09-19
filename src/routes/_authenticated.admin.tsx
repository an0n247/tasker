import { createFileRoute, redirect } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { AdminPanel } from "@/components/AdminPanel";
import { AccessDenied } from "@/components/admin/AccessDenied";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { useQuery } from "@tanstack/react-query";
import { Shield, Loader2 } from "lucide-react";

export const Route = createFileRoute("/_authenticated/admin")({
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
  head: () => ({
    title: "Master Admin Console | Noble Gain",
    meta: [
      {
        name: "description",
        content: "Comprehensive administrative control center for Noble Gain management.",
      },
    ],
  }),
  component: AdminRouteComponent,
});

function AdminRouteComponent() {
  const { userId } = Route.useLoaderData();

  const { data: roles, isLoading } = useQuery({
    queryKey: ["admin-role-check", userId],
    queryFn: async () => {
      const [{ data: isAdmin }, { data: isModerator }, { data: isTasker }, { data: isTaskManager }] =
        await Promise.all([
          supabase.rpc("has_role", { _user_id: userId, _role: "admin" }),
          supabase.rpc("has_role", { _user_id: userId, _role: "moderator" }),
          supabase.rpc("has_role", { _user_id: userId, _role: "tasker" }),
          supabase.rpc("has_role", { _user_id: userId, _role: "task_manager" }),
        ]);
      return { isAdmin, isModerator, isTasker, isTaskManager };
    },
  });

  if (isLoading) {
    return (
      <div className="min-h-screen flex flex-col bg-background text-foreground">
        <div className="min-h-[60vh] flex-1 flex items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <Loader2 className="size-8 animate-spin text-primary" />
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">
              Verifying Security Credentials...
            </p>
          </div>
        </div>
      </div>
    );
  }

  const isAuthorized =
    roles?.isAdmin || roles?.isModerator || roles?.isTasker || roles?.isTaskManager;

  if (!isAuthorized) {
    return (
      <div className="min-h-screen flex flex-col bg-background text-foreground">
        <AdminHeader roleTitle="Unauthorized" />
        <div className="flex-1 flex items-center justify-center py-16">
          <AccessDenied />
        </div>
      </div>
    );
  }

  const roleTitle = roles?.isAdmin
    ? "Super Admin"
    : roles?.isTaskManager
    ? "Task Manager"
    : roles?.isModerator
    ? "Moderator"
    : "Admin Staff";

  return (
    <div className="min-h-screen flex flex-col bg-background text-foreground selection:bg-primary/20">
      <AdminHeader roleTitle={roleTitle} />

      <div className="flex-1 w-full max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8">
        {/* Header Banner */}
        <header className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-border/60 pb-6">
          <div className="space-y-1.5">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 border border-primary/25 text-[11px] font-black text-primary tracking-widest uppercase">
              <Shield className="size-3.5" />
              <span>Master Command Center</span>
              <span className="text-muted-foreground/40">•</span>
              <span className="text-muted-foreground font-semibold">System Administration</span>
            </div>
            <h1 className="text-3xl sm:text-4xl font-black tracking-tight text-foreground">
              Admin <span className="text-primary">Command Center</span>
            </h1>
            <p className="text-sm font-medium text-muted-foreground">
              Manage rewards marketplace, member submissions, system tasks, and cryptographic audit logs.
            </p>
          </div>

          <div className="flex items-center gap-2 bg-card px-3.5 py-2 rounded-2xl border border-border/60 shadow-xs">
            <div className="size-2 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-xs font-bold text-foreground">
              {roles?.isAdmin ? "Administrator Mode" : "Moderator Mode"}
            </span>
          </div>
        </header>

        <AdminPanel />
      </div>
    </div>
  );
}
