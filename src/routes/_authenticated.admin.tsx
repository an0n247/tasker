import { createFileRoute, redirect } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { AdminPanel } from "@/components/AdminPanel";
import { AccessDenied } from "@/components/admin/AccessDenied";
import { useQuery } from "@tanstack/react-query";
import { Shield, ShieldAlert, Sparkles, LayoutDashboard, Loader2 } from "lucide-react";
import { motion } from "framer-motion";

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
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="size-8 animate-spin text-gold" />
          <p className="text-xs font-bold text-ink-muted uppercase tracking-wider">
            Verifying Security Credentials...
          </p>
        </div>
      </div>
    );
  }

  const isAuthorized =
    roles?.isAdmin || roles?.isModerator || roles?.isTasker || roles?.isTaskManager;

  if (!isAuthorized) {
    return (
      <div className="py-12">
        <AccessDenied />
      </div>
    );
  }

  return (
    <div className="w-full max-w-7xl mx-auto pb-16 space-y-8">
      {/* Background ambient light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header Banner */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Shield className="size-3.5" />
            <span>Master Console</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Platform Administration</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Admin <span className="text-gold">Command Center</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Manage rewards marketplace, member submissions, system tasks, and cryptographic audit
            logs.
          </p>
        </div>

        <div className="flex items-center gap-2 bg-ink-2/80 px-3.5 py-2 rounded-2xl border border-hairline shadow-sm">
          <div className="size-2 rounded-full bg-emerald-500 animate-pulse" />
          <span className="text-xs font-bold text-ink-fg">
            {roles?.isAdmin ? "Administrator Mode" : "Moderator Mode"}
          </span>
        </div>
      </header>

      <AdminPanel />
    </div>
  );
}
