import { createFileRoute, redirect, Outlet } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useRealtimeBalance } from "@/hooks/use-realtime-balance";

function AuthenticatedLayout() {
  useRealtimeBalance();
  return <Outlet />;
}

export const Route = createFileRoute("/_authenticated")({
  // Sessions live in browser storage, so the server can never see them.
  // Rendering this subtree client-only prevents the SSR pass from redirecting
  // signed-in users to /auth on a hard refresh.
  ssr: false,
  beforeLoad: async ({ location }) => {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
      throw redirect({
        to: "/auth",
        search: {
          redirect: location.pathname,
        },
      });
    }

    return { user: data.user };
  },
  component: AuthenticatedLayout,
});
