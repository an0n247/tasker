import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  Users,
  Coins,
  ShoppingBag,
  TrendingUp,
  ArrowUpRight,
  ArrowDownRight,
  Clock,
  Loader2,
  
  ChevronDown,
  Sparkles,
  Shield,
  Sliders,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { RedemptionsManager } from "./admin/RedemptionsManager";
import { RewardsManager } from "./admin/RewardsManager";
import { UsersManager } from "./admin/UsersManager";
import { TasksManager } from "./admin/TasksManager";
import { TaskSubmissions } from "./admin/TaskSubmissions";
import { AnalyticsView } from "./admin/AnalyticsView";
import { PlatformSettings } from "./admin/PlatformSettings";
import { FraudManager } from "./admin/FraudManager";
import { PointsAuditLogs } from "./admin/PointsAuditLogs";
import { cn } from "@/lib/utils";
import { ListTodo, PieChart, TrendingDown, Settings, ClipboardList } from "lucide-react";
import { subDays, startOfDay } from "date-fns";
import { useState, useEffect } from "react";
import { useAuth } from "@/hooks/use-auth";
import { Lock } from "lucide-react";
import { motion } from "framer-motion";

const fadeInUp = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.45, ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number] },
  },
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

export function AdminPanel() {
  const { role, isAdmin } = useAuth();
  const queryClient = useQueryClient();

  const { data: permissions } = useQuery({
    queryKey: ["rolePermissions", role],
    queryFn: async () => {
      if (role === "admin") return null;
      const { data } = await supabase
        .from("role_permissions")
        .select("tab_name")
        .eq("role", role)
        .eq("is_enabled", true);
      return data?.map((p) => p.tab_name) || [];
    },
    enabled: !!role,
  });

  const { data: stats, isLoading } = useQuery({
    queryKey: ["adminStats"],
    queryFn: async () => {
      const now = new Date();
      const thirtyDaysAgo = subDays(startOfDay(now), 30);
      const sixtyDaysAgo = subDays(startOfDay(now), 60);

      const [usersRes, usersPrevRes, pointsRes, pointsPrevRes, redemptionsRes, redemptionsPrevRes] =
        await Promise.all([
          supabase.from("profiles").select("id", { count: "exact", head: true }),
          supabase
            .from("profiles")
            .select("id", { count: "exact", head: true })
            .lt("created_at", thirtyDaysAgo.toISOString()),
          supabase
            .from("points_transactions")
            .select("amount")
            .gte("created_at", thirtyDaysAgo.toISOString()),
          supabase
            .from("points_transactions")
            .select("amount")
            .gte("created_at", sixtyDaysAgo.toISOString())
            .lt("created_at", thirtyDaysAgo.toISOString()),
          supabase
            .from("redemptions")
            .select("id", { count: "exact", head: true })
            .gte("created_at", thirtyDaysAgo.toISOString()),
          supabase
            .from("redemptions")
            .select("id", { count: "exact", head: true })
            .gte("created_at", sixtyDaysAgo.toISOString())
            .lt("created_at", thirtyDaysAgo.toISOString()),
        ]);

      const totalUsers = usersRes.count || 0;
      const prevUsers = usersPrevRes.count || 0;

      const pointsIssued =
        pointsRes.data?.reduce((acc, curr) => acc + (curr.amount > 0 ? curr.amount : 0), 0) || 0;
      const prevPointsIssued =
        pointsPrevRes.data?.reduce((acc, curr) => acc + (curr.amount > 0 ? curr.amount : 0), 0) ||
        0;

      const pointsSpent = Math.abs(
        pointsRes.data?.reduce((acc, curr) => acc + (curr.amount < 0 ? curr.amount : 0), 0) || 0,
      );
      const prevPointsSpent = Math.abs(
        pointsPrevRes.data?.reduce((acc, curr) => acc + (curr.amount < 0 ? curr.amount : 0), 0) ||
          0,
      );

      const totalRedemptions = redemptionsRes.count || 0;
      const prevRedemptions = redemptionsPrevRes.count || 0;

      const calculateTrend = (current: number, previous: number) => {
        if (previous === 0) return { trend: current > 0 ? "+100%" : "0%", up: true };
        const diff = current - previous;
        const percentage = Math.round((Math.abs(diff) / previous) * 100);
        return {
          trend: `${diff >= 0 ? "+" : "-"}${percentage}%`,
          up: diff >= 0,
        };
      };

      return {
        totalUsers,
        totalPoints: pointsIssued,
        pointsSpent,
        totalRedemptions,
        redemptionRate: usersRes.count
          ? ((redemptionsRes.count || 0) / usersRes.count).toFixed(2)
          : 0,
        trends: {
          users: calculateTrend(totalUsers, prevUsers),
          points: calculateTrend(pointsIssued, prevPointsIssued),
          spent: calculateTrend(pointsSpent, prevPointsSpent),
          redemptions: calculateTrend(totalRedemptions, prevRedemptions),
        },
      };
    },
    enabled: isAdmin,
  });

  const [activeTab, setActiveTab] = useState(() => {
    if (typeof window !== "undefined") {
      const savedTab = localStorage.getItem("noblegain_admin_last_tab");
      return savedTab === "fraud"
        ? "audit"
        : savedTab === "verifications"
          ? "approvals"
          : savedTab === "referrals"
            ? "analytics"
            : savedTab || "users";
    }
    return "users";
  });


  useEffect(() => {
    localStorage.setItem("noblegain_admin_last_tab", activeTab);
  }, [activeTab]);

  useEffect(() => {
    const channel = supabase
      .channel("admin-stats-realtime")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "points_transactions",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["adminStats"] });
        },
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "profiles",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["adminStats"] });
        },
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "redemptions",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["adminStats"] });
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const tabs = [
    { value: "analytics", icon: PieChart, label: "Analytics" },
    { value: "users", icon: Users, label: "Users" },
    { value: "tasks", icon: ListTodo, label: "Tasks" },
    { value: "approvals", icon: Clock, label: "Submissions" },
    { value: "rewards", icon: ShoppingBag, label: "Rewards" },
    { value: "redemptions", icon: Clock, label: "Redemptions" },
    
    { value: "audit", icon: ClipboardList, label: "Audit Logs" },
    { value: "settings", icon: isAdmin ? Settings : Lock, label: "Settings" },
  ];

  const filteredTabs = tabs.filter((tab) => {
    if (isAdmin) return true;
    if (!permissions) return false;
    return tab.value === "audit"
      ? permissions.includes("audit") || permissions.includes("fraud")
      : tab.value === "approvals"
        ? permissions.includes("approvals") || permissions.includes("verifications")
        : permissions.includes(tab.value);
  });

  useEffect(() => {
    if (filteredTabs.length > 0 && !filteredTabs.some((tab) => tab.value === activeTab)) {
      const firstTab = filteredTabs[0];
      if (firstTab) setActiveTab(firstTab.value);
    }
  }, [activeTab, filteredTabs]);

  const statCards = [
    {
      title: "Total Registered Users",
      value: stats?.totalUsers.toLocaleString() || "0",
      icon: Users,
      iconColor: "text-gold",
      iconBg: "bg-gold/15 border-gold/25",
      trend: stats?.trends.users.trend || "0%",
      trendUp: stats?.trends.users.up ?? true,
      description: "Active members",
    },
    {
      title: "Points Distributed",
      value: stats?.totalPoints.toLocaleString() || "0",
      icon: Coins,
      iconColor: "text-emerald-400",
      iconBg: "bg-emerald-500/15 border-emerald-500/25",
      trend: stats?.trends.points.trend || "0%",
      trendUp: stats?.trends.points.up ?? true,
      description: "Last 30 days",
    },
    {
      title: "Points Redeemed",
      value: stats?.pointsSpent.toLocaleString() || "0",
      icon: ShoppingBag,
      iconColor: "text-purple-400",
      iconBg: "bg-purple-500/15 border-purple-500/25",
      trend: stats?.trends.spent.trend || "0%",
      trendUp: stats?.trends.spent.up ?? true,
      description: "Vault claims",
    },
    {
      title: "Total Redemptions",
      value: stats?.totalRedemptions.toLocaleString() || "0",
      icon: TrendingUp,
      iconColor: "text-blue-400",
      iconBg: "bg-blue-500/15 border-blue-500/25",
      trend: stats?.trends.redemptions.trend || "0%",
      trendUp: stats?.trends.redemptions.up ?? true,
      description: "Completed orders",
    },
  ];

  if (isLoading) {
    return (
      <div className="flex h-[350px] w-full items-center justify-center">
        <Loader2 className="size-8 animate-spin text-gold" />
      </div>
    );
  }

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8"
    >
      {/* 4 Bento KPI Metric Cards */}
      <motion.div
        variants={fadeInUp}
        className="grid gap-4 grid-cols-1 sm:grid-cols-2 lg:grid-cols-4"
      >
        {statCards.map((stat) => (
          <div
            key={stat.title}
            className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl group hover:border-gold/30 transition-all duration-300 space-y-3"
          >
            <div className="flex items-center justify-between">
              <span className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">
                {stat.title}
              </span>
              <div
                className={cn(
                  "size-8 rounded-xl flex items-center justify-center border",
                  stat.iconBg,
                  stat.iconColor,
                )}
              >
                <stat.icon className="size-4" />
              </div>
            </div>

            <div>
              <div className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-ink-fg">
                {stat.value}
              </div>
              <div className="flex items-center gap-2 mt-1.5">
                <span
                  className={cn(
                    "flex items-center text-[10px] font-black px-2 py-0.5 rounded-md border",
                    stat.trendUp
                      ? "text-emerald-400 bg-emerald-500/15 border-emerald-500/30"
                      : "text-rose-400 bg-rose-500/15 border-rose-500/30",
                  )}
                >
                  {stat.trendUp ? (
                    <ArrowUpRight className="size-3 mr-0.5" />
                  ) : (
                    <ArrowDownRight className="size-3 mr-0.5" />
                  )}
                  {stat.trend}
                </span>
                <p className="text-[11px] text-ink-muted font-medium">{stat.description}</p>
              </div>
            </div>
          </div>
        ))}
      </motion.div>

      {/* Main Admin Tabbed Suite */}
      <motion.div variants={fadeInUp} className="space-y-6">
        {/* Navigation Tabs Bar */}
        <div className="flex p-1.5 bg-ink-2/80 rounded-2xl border border-hairline shadow-sm overflow-x-auto scrollbar-none gap-1">
          {filteredTabs.map((tab) => {
            const isActive = activeTab === tab.value;
            return (
              <Button
                key={tab.value}
                type="button"
                variant="ghost"
                onClick={() => setActiveTab(tab.value)}
                className={cn(
                  "flex items-center gap-2 px-4 py-2.5 rounded-xl text-xs font-bold transition-all cursor-pointer whitespace-nowrap shrink-0",
                  isActive
                    ? "bg-gold text-ink font-black shadow-md shadow-gold/10"
                    : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
                )}
              >
                <tab.icon className={cn("size-3.5", isActive ? "text-ink" : "text-gold/80")} />
                <span>{tab.label}</span>
              </Button>
            );
          })}
        </div>

        {/* Tab Panels */}
        <div className="pt-2">
          {activeTab === "analytics" && <AnalyticsView />}
          {activeTab === "users" && <UsersManager />}
          {activeTab === "tasks" && <TasksManager />}
          {activeTab === "approvals" && <TaskSubmissions />}
          {activeTab === "rewards" && <RewardsManager />}
          {activeTab === "redemptions" && <RedemptionsManager />}
          
          {activeTab === "audit" && (
            <div className="space-y-8">
              <PointsAuditLogs />
              <FraudManager />
            </div>
          )}

          {activeTab === "settings" && <PlatformSettings />}
        </div>
      </motion.div>
    </motion.div>
  );
}
