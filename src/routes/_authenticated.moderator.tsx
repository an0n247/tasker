import { createFileRoute, redirect } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { AdminPanel } from "@/components/AdminPanel";
import { AccessDenied } from "@/components/admin/AccessDenied";
import { AdminHeader } from "@/components/admin/AdminHeader";
import { useQuery } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

export const Route = createFileRoute("/_authenticated/moderator")({
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
  component: ModeratorRouteComponent,
});

function ModeratorRouteComponent() {
  const { userId } = Route.useLoaderData();

  const { data: roles, isLoading } = useQuery({
    queryKey: ["moderator-role-check", userId],
    queryFn: async () => {
      const [{ data: isAdmin }, { data: isModerator }] = await Promise.all([
        supabase.rpc("has_role", { _user_id: userId, _role: "admin" as any }),
        supabase.rpc("has_role", { _user_id: userId, _role: "moderator" as any }),
      ]);
      return { isAdmin, isModerator };
    },
  });

  if (isLoading) {
    return (
      <div className="min-h-screen flex flex-col bg-background text-foreground">
        <div className="min-h-[60vh] flex-1 flex items-center justify-center">
          <div className="flex flex-col items-center gap-3">
            <Loader2 className="size-8 animate-spin text-primary" />
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">
              Verifying Moderator Credentials...
            </p>
          </div>
        </div>
      </div>
    );
  }

  const isAuthorized = roles?.isAdmin || roles?.isModerator;

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

  return (
    <div className="min-h-screen flex flex-col bg-background text-foreground selection:bg-primary/20">
      <AdminHeader roleTitle="Moderator" />
      <div className="flex-1 w-full max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
        <div className="flex flex-col gap-1.5 border-b border-border/60 pb-4">
          <h1 className="text-3xl font-black tracking-tight text-foreground uppercase">
            Moderator Console
          </h1>
          <p className="text-sm text-muted-foreground font-medium">
            Review tasks, handle redemptions, and monitor platform activity.
          </p>
        </div>
        <AdminPanel />
      </div>
    </div>
  );
}
