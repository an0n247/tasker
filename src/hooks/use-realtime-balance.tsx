import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

/**
 * Keeps user point balance, notifications, streak, and task submissions fresh in real time.
 * Listens to postgres realtime events on profiles, points_transactions, notifications, and task_submissions.
 */
export function useRealtimeBalance() {
  const queryClient = useQueryClient();

  useEffect(() => {
    let channel: ReturnType<typeof supabase.channel> | null = null;
    let cancelled = false;

    const invalidateAll = () => {
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["recentTransactions"] });
      queryClient.invalidateQueries({ queryKey: ["transactions"] });
      queryClient.invalidateQueries({ queryKey: ["balanceTrend"] });
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
      queryClient.invalidateQueries({ queryKey: ["my-submissions"] });
      queryClient.invalidateQueries({ queryKey: ["task-submissions"] });
      queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
      queryClient.invalidateQueries({ queryKey: ["streak"] });
    };

    const setup = async () => {
      const { data } = await supabase.auth.getUser();
      const userId = data.user?.id;
      if (!userId || cancelled) return;

      channel = supabase
        .channel(`user-realtime-hub-${userId}`)
        // 1. Profile Balance Updates
        .on(
          "postgres_changes",
          {
            event: "UPDATE",
            schema: "public",
            table: "profiles",
            filter: `id=eq.${userId}`,
          },
          () => {
            queryClient.invalidateQueries({ queryKey: ["profile"] });
            queryClient.invalidateQueries({ queryKey: ["balanceTrend"] });
          },
        )
        // 2. Points Transactions (Earned, Redeemed, Bonuses)
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "points_transactions",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            invalidateAll();
            if (payload.eventType === "INSERT" && payload.new) {
              const row = payload.new as any;
              if (row.amount > 0) {
                toast.success(`+${row.amount} PTS Credited!`, {
                  description: row.description || "Points added to your vault.",
                });
              }
            }
          },
        )
        // 3. Instant In-App Notifications (Task approvals, Rewards, Streaks)
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "notifications",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            queryClient.invalidateQueries({ queryKey: ["notifications"] });
            if (payload.eventType === "INSERT" && payload.new) {
              const n = payload.new as any;
              toast.info(n.title || "New Notification", {
                description: n.message,
              });
            }
          },
        )
        // 4. Task Submissions & Verifications
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "task_submissions",
            filter: `user_id=eq.${userId}`,
          },
          (payload) => {
            queryClient.invalidateQueries({ queryKey: ["my-submissions"] });
            queryClient.invalidateQueries({ queryKey: ["task-submissions"] });
            queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
            invalidateAll();

            if (payload.eventType === "UPDATE" && payload.new) {
              const sub = payload.new as any;
              if (sub.status === "verified" || sub.status === "approved") {
                toast.success("Task Approved!", {
                  description: "Your task submission has been verified and points rewarded.",
                });
              } else if (sub.status === "rejected") {
                toast.error("Task Submission Rejected", {
                  description: sub.admin_note || "Please review requirements and try again.",
                });
              }
            }
          },
        )
        // 5. Streaks
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "user_streaks",
            filter: `user_id=eq.${userId}`,
          },
          () => {
            queryClient.invalidateQueries({ queryKey: ["streak"] });
          },
        )
        .subscribe();
    };

    setup();

    // Safety net refresh on tab focus
    const onVisible = () => {
      if (document.visibilityState === "visible") invalidateAll();
    };
    document.addEventListener("visibilitychange", onVisible);

    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", onVisible);
      if (channel) supabase.removeChannel(channel);
    };
  }, [queryClient]);
}
