import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Coins,
  Gift,
  Share2,
  TrendingUp,
  TrendingDown,
  Clock,
  ChevronRight,
  Award,
  Zap,
  Star,
  CheckCircle2,
  Sparkles,
  Crown,
  Copy,
  ExternalLink,
  Flame,
  ArrowUpRight,
  ShieldCheck,
  Target,
  Check,
  DollarSign,
  ArrowRight,
  HelpCircle,
  Activity,
  Layers,
  Percent,
  AlertCircle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { subDays, startOfDay } from "date-fns";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import confetti from "canvas-confetti";
import { cn } from "@/lib/utils";
import { motion, AnimatePresence } from "framer-motion";
import { useState } from "react";

export const Route = createFileRoute("/_authenticated/dashboard")({
  head: () => ({
    title: "Member Dashboard | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Manage your rewards, track your daily streaks, and watch your points balance grow on your Noble Gain dashboard.",
      },
      { property: "og:title", content: "Member Dashboard | Noble Gain" },
      {
        property: "og:description",
        content:
          "See your latest earnings, claim daily bonuses, and track your progress toward your next big reward.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Dashboard,
});

const fadeInUp = {
  hidden: { opacity: 0, y: 18 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number] },
  },
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08 },
  },
};

function Dashboard() {
  const queryClient = useQueryClient();
  const [copiedLink, setCopiedLink] = useState(false);

  const { data: profile } = useQuery({
    queryKey: ["profile"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return null;
      const { data } = await supabase.from("profiles").select("*").eq("id", user.id).single();
      return data;
    },
  });

  const { data: streak } = useQuery({
    queryKey: ["streak"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return null;
      const { data } = await supabase
        .from("user_streaks")
        .select("*")
        .eq("user_id", user.id)
        .single();
      return data;
    },
  });

  const { data: referralCount } = useQuery({
    queryKey: ["referralCount"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return 0;
      const { count } = await supabase
        .from("referrals")
        .select("*", { count: "exact", head: true })
        .eq("referrer_id", user.id);
      return count || 0;
    },
  });

  const { data: featuredTasks } = useQuery({
    queryKey: ["featured-tasks"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return [];

      const { data: tasks, error } = await supabase
        .from("tasks")
        .select(
          `
          *,
          task_submissions(status)
        `,
        )
        .eq("is_active", true)
        .eq("is_featured", true)
        .limit(3);

      if (error) throw error;
      return tasks;
    },
  });

  const { data: dailyStats } = useQuery({
    queryKey: ["daily-task-stats"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return { daily_count: 0 };

      const { data, error } = await supabase
        .from("user_daily_task_counts" as any)
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();

      if (error) console.error("Error fetching daily stats:", error);
      return (data as any) || { daily_count: 0 };
    },
  });

  const dailyLimitReached = (dailyStats?.daily_count || 0) >= 10;

  const claimDailyStreak = useMutation({
    mutationFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");
      const { data, error } = await supabase.rpc("claim_daily_reward", { _user_id: user.id });
      if (error) throw new Error(error.message || "An unexpected error occurred.");
      const result = data as any;
      if (!result.success) throw new Error(result.message || "Failed to claim reward");
      return result;
    },
    onSuccess: (result) => {
      confetti({
        particleCount: 90,
        spread: 70,
        origin: { y: 0.6 },
        colors: ["#002d26", "#e6c17a", "#10b981", "#f59e0b"],
      });
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["streak"] });
      queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
      queryClient.invalidateQueries({ queryKey: ["recentTransactions"] });
      toast.success(result.message || `Daily bonus claimed! +${result.points} points`);
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to claim reward.");
    },
  });

  const { data: recentTransactions } = useQuery({
    queryKey: ["recentTransactions"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return [];
      const { data } = await supabase
        .from("points_transactions")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false })
        .limit(6);
      return data;
    },
  });

  const { data: balanceTrend } = useQuery({
    queryKey: ["balanceTrend"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return { percentage: 0, isPositive: true };

      const now = new Date();
      const sevenDaysAgo = subDays(startOfDay(now), 7);
      const fourteenDaysAgo = subDays(startOfDay(now), 14);

      const { data: currentWeekData } = await supabase
        .from("points_transactions")
        .select("amount")
        .eq("user_id", user.id)
        .gt("amount", 0)
        .gte("created_at", sevenDaysAgo.toISOString());

      const { data: previousWeekData } = await supabase
        .from("points_transactions")
        .select("amount")
        .eq("user_id", user.id)
        .gt("amount", 0)
        .gte("created_at", fourteenDaysAgo.toISOString())
        .lt("created_at", sevenDaysAgo.toISOString());

      const currentTotal = currentWeekData?.reduce((acc, tx) => acc + tx.amount, 0) || 0;
      const previousTotal = previousWeekData?.reduce((acc, tx) => acc + tx.amount, 0) || 0;

      if (previousTotal === 0) {
        return { percentage: currentTotal > 0 ? 100 : 0, isPositive: true };
      }

      const diff = currentTotal - previousTotal;
      const percentage = Math.round((Math.abs(diff) / previousTotal) * 100);

      return {
        percentage,
        isPositive: diff >= 0,
      };
    },
  });

  const isClaimedToday =
    streak?.last_activity_at &&
    new Date(streak.last_activity_at).toDateString() === new Date().toDateString();
  const currentPoints = profile?.points_balance || 0;
  const estimatedUsdValue = (currentPoints / 1000).toFixed(2);

  // Tier calculation logic
  const getTierInfo = (points: number) => {
    if (points >= 25000)
      return {
        name: "Diamond VIP",
        nextTier: "Max Tier",
        target: 25000,
        progress: 100,
        color: "text-sky-400",
        badgeBg: "bg-sky-500/15 border-sky-500/30 text-sky-400",
        icon: Crown,
      };
    if (points >= 10000)
      return {
        name: "Gold Elite",
        nextTier: "Diamond VIP",
        target: 25000,
        progress: Math.min(100, Math.round((points / 25000) * 100)),
        color: "text-gold",
        badgeBg: "bg-gold/15 border-gold/30 text-gold",
        icon: Award,
      };
    if (points >= 3000)
      return {
        name: "Silver Member",
        nextTier: "Gold Elite",
        target: 10000,
        progress: Math.min(100, Math.round((points / 10000) * 100)),
        color: "text-slate-300",
        badgeBg: "bg-slate-500/15 border-slate-400/30 text-slate-300",
        icon: Sparkles,
      };
    return {
      name: "Bronze Starter",
      nextTier: "Silver Member",
      target: 3000,
      progress: Math.min(100, Math.round((points / 3000) * 100)),
      color: "text-amber-500",
      badgeBg: "bg-amber-500/15 border-amber-500/30 text-amber-500",
      icon: Star,
    };
  };

  const tier = getTierInfo(currentPoints);

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  };

  const displayName = profile?.username
    ? profile.username.charAt(0).toUpperCase() + profile.username.slice(1)
    : profile?.full_name?.split(" ")[0] || "Member";

  const referralCode = profile?.referral_code || profile?.id?.slice(0, 8) || "";
  const referralLink =
    typeof window !== "undefined"
      ? `${window.location.origin}/auth?ref=${referralCode}&mode=signup`
      : `/auth?ref=${referralCode}&mode=signup`;

  const referralShareMessage = `🚀 Join me on Noble Gain and start earning real rewards and cash for completing quick daily tasks! Sign up with my invite link to get a 50 PTS welcome bonus:\n\n${referralLink}\n\nInvite Code: ${referralCode}`;

  const hasCompletedSocialProfile = Boolean(
    profile?.twitter_handle ||
    profile?.telegram_handle ||
    profile?.instagram_handle ||
    profile?.facebook_handle,
  );

  const handleCopyReferral = () => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(referralShareMessage);
      setCopiedLink(true);
      toast.success("Invite message & link copied to clipboard!");
      setTimeout(() => setCopiedLink(false), 2500);
    }
  };

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-7xl mx-auto pb-12"
    >
      {/* Background ambient lighting */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header Greeting Banner */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Sparkles className="size-3.5" />
            <span>{tier.name}</span>
            <span className="text-hairline">•</span>
            {hasCompletedSocialProfile ? (
              <span className="text-emerald-400 font-bold flex items-center gap-1">
                <CheckCircle2 className="size-3 text-emerald-400" />
                Verified Account
              </span>
            ) : (
              <Link
                to="/profile"
                className="text-amber-400 hover:text-amber-300 font-bold flex items-center gap-1 hover:underline transition-colors"
                title="Complete your social profiles to verify your account"
              >
                <AlertCircle className="size-3 text-amber-400" />
                Incomplete Profile
              </Link>
            )}
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            {getGreeting()}, <span className="text-gold">{displayName}</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Track your balance, maintain your daily streak, and unlock instant reward redemptions.
          </p>
        </div>

        {/* Action Buttons */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={handleCopyReferral}
            className="h-11 rounded-xl px-4 text-xs font-bold border border-hairline bg-ink-2/80 text-ink-fg hover:border-gold/30 hover:bg-ink-3 transition-all flex items-center gap-2 cursor-pointer shadow-sm"
          >
            {copiedLink ? (
              <Check className="size-4 text-emerald-400" />
            ) : (
              <Copy className="size-4 text-gold" />
            )}
            <span>{copiedLink ? "Link Copied!" : "Copy Invite Link"}</span>
          </button>

          <Button
            asChild
            className="h-11 rounded-xl px-5 font-bold bg-gold text-ink hover:bg-gold-soft transition-all text-xs shadow-lg shadow-gold/10 hover:-translate-y-0.5"
          >
            <Link to="/earn" search={{ tab: "tasks" }}>
              <Zap className="size-4 mr-1.5 fill-ink" />
              Earn Points
            </Link>
          </Button>
        </div>
      </motion.header>

      {/* Main Luxury Hero & Balance Showcase */}
      <motion.div variants={fadeInUp} className="grid lg:grid-cols-12 gap-6 items-stretch">
        {/* Left: Luxury Points Showcase Card */}
        <div className="lg:col-span-8 rounded-3xl p-6 sm:p-8 relative overflow-hidden bg-gradient-to-br from-[#002d26] via-[#003830] to-[#011815] text-white border border-gold/25 flex flex-col justify-between shadow-2xl min-h-[320px]">
          {/* Ambient Lighting Spheres */}
          <div className="absolute -top-20 -right-20 size-72 bg-gold/15 rounded-full blur-3xl pointer-events-none ink-breathe" />
          <div className="absolute -bottom-20 -left-20 size-72 bg-emerald-500/20 rounded-full blur-3xl pointer-events-none" />

          {/* Subtle Logo Watermark */}
          <div className="absolute top-1/2 right-4 -translate-y-1/2 opacity-[0.06] pointer-events-none hidden sm:block">
            <img src="/logo.png" alt="" className="size-64 object-contain rotate-6" />
          </div>

          <div className="relative z-10 space-y-6">
            <div className="flex items-center justify-between flex-wrap gap-2">
              <div className="flex items-center gap-3">
                <div className="size-10 rounded-xl bg-white/10 backdrop-blur-md flex items-center justify-center border border-white/15 shadow-inner">
                  <Coins className="size-5 text-gold" />
                </div>
                <div>
                  <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-white/60">
                    Noble Vault
                  </p>
                  <p className="text-xs font-semibold text-white/90">Available Points Balance</p>
                </div>
              </div>

              <div
                className={cn(
                  "inline-flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-bold border backdrop-blur-md",
                  tier.badgeBg,
                )}
              >
                <tier.icon className="size-3.5" />
                <span>{tier.name}</span>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-baseline gap-3 flex-wrap">
                <span className="text-5xl sm:text-6xl font-black tracking-tight text-white font-mono">
                  {currentPoints.toLocaleString()}
                </span>
                <span className="text-xl sm:text-2xl font-black text-gold tracking-tight">PTS</span>
                <span className="text-xs font-semibold text-white/60 pl-2">
                  (≈ ${estimatedUsdValue} USD value)
                </span>
              </div>

              <div className="flex items-center gap-2 text-xs font-semibold text-white/80">
                <div
                  className={cn(
                    "inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-[11px] font-bold",
                    balanceTrend?.isPositive
                      ? "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"
                      : "bg-rose-500/20 text-rose-300 border border-rose-500/30",
                  )}
                >
                  {balanceTrend?.isPositive ? (
                    <TrendingUp className="size-3.5" />
                  ) : (
                    <TrendingDown className="size-3.5" />
                  )}
                  {balanceTrend?.isPositive ? "+" : "-"}
                  {balanceTrend?.percentage || 0}%
                </div>
                <span>vs last 7 days</span>
              </div>
            </div>
          </div>

          {/* Tier Progress Bar & Action Buttons */}
          <div className="relative z-10 pt-6 mt-6 border-t border-white/10 space-y-4">
            <div className="space-y-2">
              <div className="flex justify-between text-xs font-bold text-white/80">
                <span className="flex items-center gap-1.5">
                  <Crown className="size-3.5 text-gold" />
                  Next Milestone: <strong className="text-white">{tier.nextTier}</strong>
                </span>
                <span className="text-gold">{tier.progress}% completed</span>
              </div>
              <div className="h-2.5 bg-black/40 rounded-full overflow-hidden p-0.5 border border-white/10">
                <motion.div
                  initial={{ width: 0 }}
                  animate={{ width: `${tier.progress}%` }}
                  transition={{
                    duration: 1.2,
                    ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number],
                  }}
                  className="h-full bg-gradient-to-r from-gold to-emerald-400 rounded-full"
                />
              </div>
            </div>

            <div className="flex flex-wrap gap-3 pt-2">
              <Button
                className="h-11 rounded-xl px-6 font-bold bg-gold text-ink hover:bg-gold-soft border-none shadow-lg shadow-black/20 hover:-translate-y-0.5 transition-all text-xs"
                asChild
              >
                <Link to="/earn" search={{ tab: "tasks" }}>
                  <span>Start Earning</span>
                  <ArrowUpRight className="size-4 ml-1.5" />
                </Link>
              </Button>
              <Button
                asChild
                className="h-11 rounded-xl px-6 font-bold bg-white/15 hover:bg-white/25 text-white border border-white/30 shadow-md shadow-black/20 hover:-translate-y-0.5 transition-all text-xs"
              >
                <Link to="/redeem">
                  <Gift className="size-4 mr-1.5 text-gold" />
                  <span>Redeem Rewards</span>
                </Link>
              </Button>
            </div>
          </div>
        </div>

        {/* Right: Daily Streak Booster Card */}
        <div className="lg:col-span-4 rounded-3xl p-6 sm:p-7 border border-hairline bg-ink-2/70 flex flex-col justify-between relative overflow-hidden shadow-xl backdrop-blur-xl group">
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="size-10 rounded-xl bg-amber-500/15 text-amber-500 flex items-center justify-center border border-amber-500/20 group-hover:scale-105 transition-transform">
                  <Flame className="size-5 fill-amber-500 text-amber-500" />
                </div>
                <div>
                  <h3 className="text-sm font-black tracking-tight text-ink-fg">Daily Streak</h3>
                  <p className="text-[11px] text-ink-muted font-medium">
                    Claim consecutive check-ins
                  </p>
                </div>
              </div>
              <Badge
                variant="outline"
                className="font-bold text-amber-500 border-amber-500/30 bg-amber-500/10 text-xs px-2.5 py-0.5"
              >
                {streak?.current_streak || 0}d Streak
              </Badge>
            </div>

            {/* Streak Day Circles Visualizer */}
            <div className="py-2">
              <div className="grid grid-cols-7 gap-1.5">
                {[1, 2, 3, 4, 5, 6, 7].map((day) => {
                  const STREAK_BONUSES = [5, 5, 10, 10, 15, 15, 20];
                  const currentStreakMod =
                    (streak?.current_streak || 0) % 7 ||
                    ((streak?.current_streak || 0) > 0 ? 7 : 0);
                  const isPassed =
                    (streak?.current_streak || 0) >= 7 ? true : currentStreakMod >= day;
                  const isCurrent =
                    (streak?.current_streak || 0) >= 7
                      ? day === 7
                      : currentStreakMod === day || (currentStreakMod === 0 && day === 1);

                  return (
                    <div
                      key={day}
                      className={cn(
                        "flex flex-col items-center justify-center p-2 rounded-xl text-center border transition-all",
                        isCurrent && !isClaimedToday
                          ? "bg-gold/20 border-gold text-gold ring-1 ring-gold shadow-sm"
                          : isPassed
                            ? "bg-emerald-500/15 border-emerald-500/30 text-emerald-400"
                            : "bg-ink-3/60 border-hairline text-ink-muted",
                      )}
                    >
                      <span className="text-[9px] font-bold uppercase">D{day}</span>
                      <span className="text-xs font-black">+{STREAK_BONUSES[day - 1]}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="rounded-2xl bg-ink-3/70 p-3.5 border border-hairline space-y-1.5 text-xs">
              <div className="flex items-center justify-between font-bold">
                <span className="text-ink-muted">Today's Status:</span>
                <span className={cn(isClaimedToday ? "text-emerald-400" : "text-gold")}>
                  {isClaimedToday ? "✓ Checked-in Today" : "⚡ Ready to Claim"}
                </span>
              </div>
              <div className="flex items-center justify-between font-bold">
                <span className="text-ink-muted">Longest Record:</span>
                <span className="text-ink-fg">{streak?.longest_streak || 0} Days</span>
              </div>
            </div>
          </div>

          <div className="pt-5">
            <Button
              className={cn(
                "w-full rounded-xl font-bold h-12 text-xs transition-all shadow-md",
                isClaimedToday
                  ? "bg-ink-3 text-ink-muted border border-hairline cursor-default hover:bg-ink-3"
                  : "bg-gradient-to-r from-gold to-[#d4af37] text-ink hover:opacity-95 hover:-translate-y-0.5",
              )}
              disabled={isClaimedToday || claimDailyStreak.isPending}
              onClick={() => claimDailyStreak.mutate()}
            >
              {claimDailyStreak.isPending ? (
                "Claiming Bonus..."
              ) : isClaimedToday ? (
                <span className="flex items-center gap-2">
                  <CheckCircle2 className="size-4 text-emerald-400" />
                  Claimed for Today
                </span>
              ) : (
                <span className="flex items-center gap-2">
                  <Sparkles className="size-4 fill-ink" />
                  Claim Day Bonus (+
                  {(() => {
                    const STREAK_BONUSES = [5, 5, 10, 10, 15, 15, 20];
                    const nextDay = (streak?.current_streak || 0) + 1;
                    if (nextDay >= 7) return 20;
                    return STREAK_BONUSES[Math.max(0, nextDay - 1)] || 5;
                  })()}{" "}
                  PTS)
                </span>
              )}
            </Button>
          </div>
        </div>
      </motion.div>

      {/* 4-Card Bento Metric Grid */}
      <motion.div variants={fadeInUp} className="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        {/* Card 1: Total Points Earned */}
        <div className="rounded-2xl p-5 sm:p-6 bg-ink-2/60 border border-hairline shadow-md hover:border-gold/30 transition-all hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[11px] font-bold uppercase tracking-widest text-ink-muted">
              Points Balance
            </span>
            <div className="size-9 rounded-xl bg-gold/10 text-gold flex items-center justify-center border border-gold/20">
              <Coins className="size-4.5" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black tracking-tight text-ink-fg font-mono">
            {currentPoints.toLocaleString()}
          </p>
          <p className="text-xs font-semibold text-ink-muted mt-1.5 flex items-center gap-1">
            <ShieldCheck className="size-3.5 text-gold" />
            Verified & Redeemable
          </p>
        </div>

        {/* Card 2: Lifetime Referrals */}
        <div className="rounded-2xl p-5 sm:p-6 bg-ink-2/60 border border-hairline shadow-md hover:border-gold/30 transition-all hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[11px] font-bold uppercase tracking-widest text-ink-muted">
              Referral Network
            </span>
            <div className="size-9 rounded-xl bg-sky-500/10 text-sky-400 flex items-center justify-center border border-sky-500/20">
              <Share2 className="size-4.5" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black tracking-tight text-ink-fg font-mono">
            {referralCount}
          </p>
          <p className="text-xs font-semibold text-ink-muted mt-1.5">+50 PTS per active invite</p>
        </div>

        {/* Card 3: Daily Task Count */}
        <div className="rounded-2xl p-5 sm:p-6 bg-ink-2/60 border border-hairline shadow-md hover:border-gold/30 transition-all hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[11px] font-bold uppercase tracking-widest text-ink-muted">
              Daily Tasks Limit
            </span>
            <div className="size-9 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center border border-emerald-500/20">
              <Target className="size-4.5" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black tracking-tight text-ink-fg font-mono">
            {dailyStats?.daily_count || 0}{" "}
            <span className="text-sm font-bold text-ink-muted">/ 10</span>
          </p>
          <p className="text-xs font-semibold text-ink-muted mt-1.5">
            {10 - (dailyStats?.daily_count || 0)} available today
          </p>
        </div>

        {/* Card 4: VIP Tier Rank */}
        <div className="rounded-2xl p-5 sm:p-6 bg-ink-2/60 border border-hairline shadow-md hover:border-gold/30 transition-all hover:-translate-y-0.5">
          <div className="flex items-center justify-between mb-4">
            <span className="text-[11px] font-bold uppercase tracking-widest text-ink-muted">
              Member Tier
            </span>
            <div className="size-9 rounded-xl bg-amber-500/10 text-amber-500 flex items-center justify-center border border-amber-500/20">
              <Crown className="size-4.5" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black tracking-tight text-ink-fg">
            {tier.name.split(" ")[0]}
          </p>
          <p className="text-xs font-bold text-gold mt-1.5">
            {tier.progress}% to {tier.nextTier}
          </p>
        </div>
      </motion.div>

      {/* Featured Missions / High Priority Tasks */}
      {featuredTasks && featuredTasks.length > 0 && (
        <motion.section variants={fadeInUp} className="space-y-4">
          <div className="flex items-center justify-between px-1">
            <div className="flex items-center gap-2.5">
              <div className="size-8 rounded-xl bg-gold/10 flex items-center justify-center text-gold border border-gold/20">
                <Star className="size-4 fill-gold" />
              </div>
              <h2 className="text-xl font-black tracking-tight text-ink-fg">
                Featured Opportunities
              </h2>
            </div>
            <Link
              to="/earn"
              search={{ tab: "tasks" }}
              className="text-xs font-bold text-gold hover:underline uppercase tracking-widest flex items-center gap-1"
            >
              View All Tasks
              <ChevronRight className="size-3.5" />
            </Link>
          </div>

          <div className="grid gap-5 grid-cols-1 md:grid-cols-3">
            {featuredTasks.map((task: any) => {
              const submission = task.task_submissions?.[0];
              const isCompleted =
                submission?.status === "verified" || submission?.status === "pending";

              return (
                <div
                  key={task.id}
                  className="rounded-3xl p-6 bg-ink-2/60 border border-hairline shadow-lg flex flex-col justify-between relative overflow-hidden group hover:border-gold/30 transition-all"
                >
                  <div className="space-y-3.5">
                    <div className="flex items-center justify-between">
                      <div className="size-11 rounded-2xl bg-gold/10 text-gold flex items-center justify-center border border-gold/20 group-hover:scale-105 transition-transform">
                        <Zap className="size-5 fill-gold" />
                      </div>
                      <Badge className="bg-gold/15 text-gold border-gold/30 font-black text-xs px-3 py-1 rounded-xl font-mono">
                        +{task.points} PTS
                      </Badge>
                    </div>

                    <div className="space-y-1.5">
                      <h3 className="text-base font-bold text-ink-fg leading-snug line-clamp-1">
                        {task.title}
                      </h3>
                      <p className="text-xs font-medium text-ink-muted line-clamp-2 leading-relaxed">
                        {task.description}
                      </p>
                    </div>
                  </div>

                  <div className="pt-5 mt-4 border-t border-hairline">
                    <Button
                      className={cn(
                        "w-full rounded-xl font-bold h-11 text-xs transition-all",
                        isCompleted
                          ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/20 shadow-none"
                          : dailyLimitReached
                            ? "bg-amber-500/15 text-amber-400 border border-amber-500/30 shadow-none"
                            : "bg-gold text-ink hover:bg-gold-soft shadow-md shadow-gold/10 hover:-translate-y-0.5",
                      )}
                      onClick={() => {
                        if (isCompleted || dailyLimitReached) return;
                        if (task.link_url) {
                          window.open(task.link_url, "_blank");
                        }
                        toast.info("Task opened! Complete it and submit proof on the Earn page.");
                      }}
                      disabled={
                        (isCompleted && submission?.status === "verified") ||
                        (!isCompleted && dailyLimitReached)
                      }
                    >
                      {isCompleted ? (
                        <span className="flex items-center gap-1.5">
                          <CheckCircle2 className="size-4 text-emerald-400" />
                          {submission?.status === "pending" ? "Verification Pending" : "Completed"}
                        </span>
                      ) : dailyLimitReached ? (
                        <span>Daily Limit Reached</span>
                      ) : (
                        <span className="flex items-center gap-1">
                          Start Task
                          <ChevronRight className="size-4 ml-1" />
                        </span>
                      )}
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        </motion.section>
      )}

      {/* Main Split Grid: Activity Stream & Referral Hub */}
      <motion.div variants={fadeInUp} className="grid gap-8 lg:grid-cols-12">
        {/* Left Column: Recent Activity Log */}
        <div className="lg:col-span-8 space-y-4">
          <div className="flex items-center justify-between px-1">
            <div className="flex items-center gap-2">
              <Activity className="size-4.5 text-gold" />
              <h2 className="text-xl font-black tracking-tight text-ink-fg">Recent Activity</h2>
            </div>
            <Link
              to="/transactions"
              className="text-xs font-bold text-gold hover:underline uppercase tracking-widest flex items-center gap-1"
            >
              View Full Ledger
              <ChevronRight className="size-3.5" />
            </Link>
          </div>

          <div className="rounded-3xl border border-hairline bg-ink-2/60 shadow-xl overflow-hidden backdrop-blur-xl">
            <div className="divide-y divide-hairline">
              {recentTransactions?.length ? (
                recentTransactions.map((tx: any) => {
                  const isPending = tx.status === "pending";
                  const isDebit = tx.amount < 0 || tx.type === "redeem" || tx.type === "redemption";
                  const isPositive = !isDebit;

                  return (
                    <div
                      key={tx.id}
                      className="flex items-center justify-between p-4 sm:p-5 hover:bg-ink-3/50 transition-colors cursor-pointer"
                      onClick={() => {
                        toast.info(
                          <div className="space-y-1.5">
                            <p className="font-bold text-sm text-ink-fg">{tx.description}</p>
                            <div className="text-xs text-ink-muted font-semibold space-y-0.5">
                              <p>
                                Amount: {isPositive ? "+" : "-"}
                                {Math.abs(tx.amount)} PTS
                              </p>
                              <p>Status: {tx.status || "completed"}</p>
                              <p>Timestamp: {new Date(tx.created_at).toLocaleString()}</p>
                            </div>
                          </div>,
                        );
                      }}
                    >
                      <div className="flex items-center gap-3.5">
                        <div
                          className={cn(
                            "size-11 rounded-2xl flex items-center justify-center transition-transform border",
                            isPending
                              ? "bg-amber-500/15 text-amber-400 border-amber-500/30"
                              : isPositive
                                ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/30"
                                : "bg-rose-500/15 text-rose-400 border-rose-500/30",
                          )}
                        >
                          {isPending ? (
                            <Clock className="size-5" />
                          ) : isPositive ? (
                            <TrendingUp className="size-5" />
                          ) : (
                            <Gift className="size-5" />
                          )}
                        </div>
                        <div className="space-y-0.5">
                          <p className="font-bold text-sm text-ink-fg flex items-center gap-2">
                            {tx.description}
                            {isPending && (
                              <Badge
                                variant="outline"
                                className="text-[10px] font-bold text-amber-400 bg-amber-500/15 border-amber-500/30"
                              >
                                Pending
                              </Badge>
                            )}
                          </p>
                          <p className="text-xs font-medium text-ink-muted">
                            {new Date(tx.created_at).toLocaleDateString(undefined, {
                              month: "short",
                              day: "numeric",
                              year: "numeric",
                            })}
                          </p>
                        </div>
                      </div>

                      <div
                        className={cn(
                          "text-base font-black font-mono",
                          isPending
                            ? "text-amber-400"
                            : isPositive
                              ? "text-emerald-400"
                              : "text-rose-400",
                        )}
                      >
                        {isPending ? "" : isPositive ? "+" : "-"}
                        {Math.abs(tx.amount).toLocaleString()} PTS
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="text-center py-16 px-4 space-y-3">
                  <div className="size-12 rounded-2xl bg-ink-3 text-ink-muted flex items-center justify-center mx-auto border border-hairline">
                    <Coins className="size-6 opacity-40" />
                  </div>
                  <p className="text-sm font-bold text-ink-muted">
                    No recent transactions recorded yet.
                  </p>
                  <Button
                    size="sm"
                    className="rounded-xl font-bold bg-gold text-ink hover:bg-gold-soft"
                    asChild
                  >
                    <Link to="/earn" search={{ tab: "tasks" }}>
                      Start First Opportunity
                    </Link>
                  </Button>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Referral Hub & Fast Redemptions */}
        <div className="lg:col-span-4 space-y-6">
          {/* Referral Booster Card */}
          <div className="space-y-3">
            <h2 className="text-xl font-black px-1 tracking-tight text-ink-fg">Invite Partners</h2>
            <div className="rounded-3xl p-6 bg-gradient-to-br from-gold/10 via-ink-2 to-ink-2/60 border border-gold/25 shadow-xl space-y-4 relative overflow-hidden backdrop-blur-xl">
              <div className="flex items-center gap-3">
                <div className="size-11 rounded-2xl bg-gold text-ink flex items-center justify-center shadow-lg shadow-gold/20">
                  <Share2 className="size-5" />
                </div>
                <div>
                  <h3 className="font-black text-sm text-ink-fg">Referral Bonus</h3>
                  <p className="text-xs font-bold text-gold">+50 PTS on their first task</p>
                </div>
              </div>

              <p className="text-xs font-medium text-ink-muted leading-relaxed">
                Invite friends and colleagues. Both you and your partner earn bonus points when they
                complete their first verified task.
              </p>

              <div className="flex items-center gap-2 p-2 rounded-xl bg-ink border border-hairline text-xs">
                <input
                  readOnly
                  value={referralLink}
                  className="bg-transparent flex-1 px-2 font-mono text-[11px] outline-none truncate text-ink-fg/90"
                />
                <Button
                  size="sm"
                  onClick={handleCopyReferral}
                  className="h-8 rounded-lg font-bold px-3 text-xs shrink-0 bg-gold text-ink hover:bg-gold-soft"
                >
                  {copiedLink ? "Copied" : "Copy"}
                </Button>
              </div>

              <Button
                variant="outline"
                className="w-full rounded-xl font-bold h-10 text-xs border-hairline hover:border-gold/30 hover:bg-ink-3 text-ink-fg transition-colors"
                asChild
              >
                <Link to="/refer">
                  Open Referral Center
                  <ChevronRight className="size-4 ml-1 text-gold" />
                </Link>
              </Button>
            </div>
          </div>

          {/* Quick Rewards Target */}
          <div className="rounded-3xl p-6 bg-ink-2/60 border border-hairline shadow-xl space-y-4 backdrop-blur-xl">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Gift className="size-5 text-gold" />
                <h3 className="font-black text-sm text-ink-fg">Next Reward Goal</h3>
              </div>
              <Badge
                variant="outline"
                className="text-[10px] font-bold text-gold border-gold/30 bg-gold/10 font-mono"
              >
                5,000 PTS
              </Badge>
            </div>

            <div className="p-3.5 rounded-2xl bg-ink-3/70 border border-hairline flex items-center gap-3">
              <div className="size-10 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center font-black text-gold text-xs">
                $5
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-bold text-ink-fg truncate">Amazon / Visa Gift Card</p>
                <p className="text-[10px] text-ink-muted font-medium">Instant digital delivery</p>
              </div>
            </div>

            <div className="space-y-1.5">
              <div className="flex justify-between text-xs font-bold text-ink-muted font-mono">
                <span>Progress: {Math.min(100, Math.round((currentPoints / 5000) * 100))}%</span>
                <span>{currentPoints} / 5,000 PTS</span>
              </div>
              <div className="h-2 bg-ink-3 rounded-full overflow-hidden border border-hairline">
                <div
                  style={{ width: `${Math.min(100, (currentPoints / 5000) * 100)}%` }}
                  className="h-full bg-gradient-to-r from-gold to-emerald-400 rounded-full transition-all duration-500"
                />
              </div>
            </div>

            <Button
              variant="outline"
              className="w-full rounded-xl font-bold h-10 text-xs border-hairline hover:border-gold/30 hover:bg-ink-3 text-ink-fg"
              asChild
            >
              <Link to="/redeem">Browse Rewards Catalog</Link>
            </Button>
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}
