import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery } from "@tanstack/react-query";
import {
  Users,
  Trophy,
  Sparkles,
  CheckCircle2,
  Clock,
  ShieldCheck,
  Gift,
  Coins,
  Share2,
  ArrowRight,
  ChevronRight,
  Zap,
  Flame,
  Crown,
  Lightbulb,
  CheckCircle,
  AlertCircle,
} from "lucide-react";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { ReferralStatsDashboard } from "@/components/ReferralStatsDashboard";
import { motion } from "framer-motion";
import { useState } from "react";

export const Route = createFileRoute("/_authenticated/refer")({
  head: () => ({
    title: "Referral Program & Network | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Invite your friends to Join Noble Gain and build a passive income stream. Earn 75 points for every referral while your friends get a 50-point head start!",
      },
      { property: "og:title", content: "Referral Program | Noble Gain Bonuses" },
      {
        property: "og:description",
        content:
          "Share your unique referral link and earn points for every friend who joins. The fastest way to grow your balance.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: ReferralPage,
});

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

function ReferralPage() {
  const [activeTab, setActiveTab] = useState<"signups" | "leaderboard">("signups");

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

  const { data: leaderboard } = useQuery({
    queryKey: ["leaderboard"],
    queryFn: async () => {
      const { data } = await supabase.from("leaderboard").select("*").limit(10);
      return data;
    },
  });

  const { data: referrals } = useQuery({
    queryKey: ["referrals", profile?.id],
    queryFn: async () => {
      if (!profile?.id) return [];

      // Safe referee summary: identity + completion booleans only (no PII exposure)
      const { data: refereesData, error: refereesError } = await supabase.rpc(
        "get_my_referees" as any,
      );

      if (refereesError) {
        console.error("Error fetching referred profiles:", refereesError);
        return [];
      }

      return (refereesData as any[]) || [];
    },
    enabled: !!profile?.id,
  });

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-7xl mx-auto pb-12"
    >
      {/* Ambient background light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header Banner */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Sparkles className="size-3.5 text-gold" />
            <span>Passive Rewards Network</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Earn +75 PTS Per Invite</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Refer & <span className="text-gold">Earn</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Invite friends to Noble Gain and earn{" "}
            <strong className="text-gold font-bold">+75 points</strong> for every qualified member.
            Your friends instantly receive a{" "}
            <strong className="text-gold font-bold">+50 points</strong> welcome bonus!
          </p>
        </div>
      </motion.header>

      {/* Referral Stats & Sharing Suite */}
      <motion.div variants={fadeInUp}>
        <ReferralStatsDashboard />
      </motion.div>

      {/* Main Split: Signups / Leaderboard & Guides */}
      <motion.div variants={fadeInUp} className="grid gap-8 lg:grid-cols-12 items-start">
        {/* Left Column: Signups & Leaderboard */}
        <div className="lg:col-span-8 space-y-6">
          <div className="flex p-1.5 bg-ink-2/80 rounded-2xl border border-hairline shadow-sm w-fit max-w-full">
            <button
              type="button"
              onClick={() => setActiveTab("signups")}
              className={cn(
                "px-5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-2",
                activeTab === "signups"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <Users className="size-3.5" />
              <span>Your Network</span>
              <span
                className={cn(
                  "px-1.5 py-0.2 rounded-md text-[10px] font-mono",
                  activeTab === "signups" ? "bg-ink/15 text-ink" : "bg-ink-3 text-ink-muted",
                )}
              >
                {referrals?.length || 0}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setActiveTab("leaderboard")}
              className={cn(
                "px-5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-2",
                activeTab === "leaderboard"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <Trophy className="size-3.5 text-amber-500" />
              <span>Global Leaderboard</span>
            </button>
          </div>

          {/* Tab 1: Recent Signups */}
          {activeTab === "signups" && (
            <div className="rounded-3xl border border-hairline bg-ink-2/70 shadow-lg overflow-hidden backdrop-blur-xl">
              <div className="p-5 sm:p-6 border-b border-hairline flex items-center justify-between">
                <div>
                  <h3 className="text-base font-black text-ink-fg">Recent Network Signups</h3>
                  <p className="text-xs text-ink-muted font-medium">
                    Track your referees' milestone verification status
                  </p>
                </div>
                <span className="font-mono text-xs font-bold text-ink-muted bg-ink-3 px-3 py-1 rounded-xl border border-hairline">
                  {referrals?.length || 0} Total
                </span>
              </div>

              <div className="p-0">
                {referrals?.length ? (
                  <div className="divide-y divide-hairline">
                    {referrals.map((ref: any) => {
                      const hasProfile = !!(ref.full_name && ref.username);
                      const hasPhone = !!ref.has_phone;
                      const hasSocial = !!ref.has_social;
                      const isComplete = hasProfile && hasPhone && hasSocial;

                      return (
                        <div
                          key={ref.id}
                          className="p-4 sm:p-5 hover:bg-ink-3/40 transition-colors"
                        >
                          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
                            <div className="flex items-center gap-3">
                              <Avatar className="size-10 border border-hairline bg-ink-3">
                                <AvatarImage src={ref.avatar_url || ""} />
                                <AvatarFallback className="bg-gold/15 text-gold text-xs font-black">
                                  {(ref.full_name?.[0] || ref.username?.[0] || "?").toUpperCase()}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <div className="flex items-center gap-2">
                                  <p className="text-sm font-bold text-ink-fg leading-none">
                                    {ref.full_name || ref.username || "Anonymous Member"}
                                  </p>
                                  {!hasSocial ? (
                                    <span className="text-[10px] font-bold bg-amber-500/15 text-amber-400 border border-amber-500/30 px-2 py-0.5 rounded-md flex items-center gap-1">
                                      <AlertCircle className="size-2.5 text-amber-400" />
                                      Pending Social Verification
                                    </span>
                                  ) : !isComplete ? (
                                    <span className="text-[10px] font-bold bg-sky-500/15 text-sky-400 border border-sky-500/30 px-2 py-0.5 rounded-md">
                                      Profile Linked
                                    </span>
                                  ) : (
                                    <span className="text-[10px] font-bold bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-md flex items-center gap-1">
                                      <CheckCircle2 className="size-2.5 text-emerald-400" />
                                      Active Member
                                    </span>
                                  )}
                                </div>
                                <p className="text-xs text-ink-muted font-medium mt-1">
                                  Joined{" "}
                                  {new Date(ref.created_at).toLocaleDateString(undefined, {
                                    month: "short",
                                    day: "numeric",
                                    year: "numeric",
                                  })}
                                </p>
                              </div>
                            </div>

                            <div>
                              <span
                                className={cn(
                                  "font-bold text-xs px-3 py-1 rounded-xl border inline-flex items-center gap-1.5",
                                  !hasSocial
                                    ? "bg-amber-500/15 text-amber-400 border-amber-500/30"
                                    : isComplete
                                      ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/30 font-black"
                                      : "bg-sky-500/15 text-sky-400 border-sky-500/30",
                                )}
                              >
                                {!hasSocial ? (
                                  <>
                                    <Clock className="size-3 text-amber-400" />
                                    <span>Pending Profile Setup</span>
                                  </>
                                ) : isComplete ? (
                                  <>
                                    <CheckCircle2 className="size-3 text-emerald-400" />
                                    <span>+75 PTS Credited</span>
                                  </>
                                ) : (
                                  <>
                                    <Clock className="size-3 text-sky-400" />
                                    <span>Pending First Task</span>
                                  </>
                                )}
                              </span>
                            </div>
                          </div>

                          {/* Checklist status */}
                          <div className="bg-ink rounded-2xl p-3.5 border border-hairline space-y-2">
                            <div className="flex items-center justify-between">
                              <span className="text-[10px] font-bold uppercase tracking-wider text-ink-muted">
                                Verification Checklist
                              </span>
                              <span
                                className={cn(
                                  "text-[10px] font-bold px-2 py-0.5 rounded-lg",
                                  isComplete
                                    ? "bg-emerald-500/15 text-emerald-400"
                                    : !hasSocial
                                      ? "bg-amber-500/15 text-amber-400"
                                      : "bg-sky-500/15 text-sky-400",
                                )}
                              >
                                {isComplete
                                  ? "Completed"
                                  : !hasSocial
                                    ? "Awaiting Social Profile"
                                    : "In Progress"}
                              </span>
                            </div>
                            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
                              <div className="flex items-center gap-1.5">
                                <div
                                  className={cn(
                                    "size-2 rounded-full",
                                    hasProfile ? "bg-emerald-500" : "bg-ink-muted/40",
                                  )}
                                />
                                <span className="text-[11px] font-medium text-ink-muted">
                                  Profile Setup
                                </span>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <div
                                  className={cn(
                                    "size-2 rounded-full",
                                    hasPhone ? "bg-emerald-500" : "bg-ink-muted/40",
                                  )}
                                />
                                <span className="text-[11px] font-medium text-ink-muted">
                                  Phone Verified
                                </span>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <div
                                  className={cn(
                                    "size-2 rounded-full",
                                    hasSocial ? "bg-emerald-500" : "bg-amber-500/60",
                                  )}
                                />
                                <span
                                  className={cn(
                                    "text-[11px] font-medium",
                                    hasSocial ? "text-emerald-400" : "text-amber-400 font-bold",
                                  )}
                                >
                                  {hasSocial ? "Social Verified" : "Social Pending"}
                                </span>
                              </div>
                              <div className="flex items-center gap-1.5">
                                <div
                                  className={cn(
                                    "size-2 rounded-full",
                                    isComplete ? "bg-emerald-500" : "bg-ink-muted/40",
                                  )}
                                />
                                <span className="text-[11px] font-medium text-ink-muted">
                                  First Task
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="p-16 text-center space-y-3">
                    <div className="size-12 rounded-2xl bg-ink-3 text-ink-muted flex items-center justify-center mx-auto border border-hairline">
                      <Users className="size-6 text-gold/40" />
                    </div>
                    <p className="text-sm font-black text-ink-fg">No network invites yet</p>
                    <p className="text-xs text-ink-muted font-medium max-w-sm mx-auto">
                      Share your unique referral link to start building your passive rewards stream
                      today!
                    </p>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Tab 2: Leaderboard */}
          {activeTab === "leaderboard" && (
            <div className="rounded-3xl border border-hairline bg-ink-2/70 shadow-lg overflow-hidden backdrop-blur-xl">
              <div className="p-5 sm:p-6 border-b border-hairline flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Trophy className="size-5 text-gold" />
                  <h3 className="text-base font-black text-ink-fg">Top Referrers Hall of Fame</h3>
                </div>
                <span className="font-mono text-xs font-bold text-ink-muted bg-ink-3 px-3 py-1 rounded-xl border border-hairline">
                  Top 10 Members
                </span>
              </div>

              <div className="divide-y divide-hairline">
                {leaderboard?.map((user, idx) => {
                  const isPodium = idx < 3;
                  const rankColors = [
                    "bg-amber-500/20 text-amber-400 border-amber-500/40",
                    "bg-slate-400/20 text-slate-300 border-slate-400/40",
                    "bg-amber-700/20 text-amber-500 border-amber-700/30",
                  ];

                  return (
                    <div
                      key={user.id}
                      className="flex items-center justify-between p-4 sm:p-5 hover:bg-ink-3/40 transition-colors"
                    >
                      <div className="flex items-center gap-3.5">
                        <div
                          className={cn(
                            "size-7 rounded-xl flex items-center justify-center text-xs font-bold border",
                            isPodium
                              ? rankColors[idx]
                              : "bg-ink-3 text-ink-muted border-hairline font-mono",
                          )}
                        >
                          {idx === 0 ? "🥇" : idx === 1 ? "🥈" : idx === 2 ? "🥉" : `#${idx + 1}`}
                        </div>

                        <div className="flex items-center gap-3">
                          <Avatar className="size-9 border border-hairline bg-ink-3">
                            <AvatarImage src={user.avatar_url || ""} />
                            <AvatarFallback className="bg-gold/15 text-gold text-xs font-black">
                              {(user.full_name?.[0] || user.username?.[0] || "?").toUpperCase()}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <p className="text-sm font-bold text-ink-fg leading-none">
                              {user.full_name || user.username || "Anonymous Member"}
                            </p>
                            <p className="text-xs text-ink-muted font-medium mt-1">
                              {idx === 0 ? "Top Referrer 👑" : "Active Partner"}
                            </p>
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <p className="text-sm font-black text-gold font-mono">
                          {(user.points_balance || 0).toLocaleString()}{" "}
                          <span className="text-xs">PTS</span>
                        </p>
                        <p className="text-[10px] text-ink-muted font-bold uppercase">
                          Total Balance
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Right Column: How It Works & Pro Tips */}
        <div className="lg:col-span-4 space-y-6">
          {/* 3-Step Visual Journey */}
          <div className="rounded-3xl p-6 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl space-y-5">
            <div className="flex items-center gap-2">
              <Sparkles className="size-4 text-gold" />
              <h3 className="font-black text-base text-ink-fg">How It Works</h3>
            </div>

            <div className="space-y-4">
              <div className="flex gap-3.5 items-start">
                <div className="size-7 rounded-xl bg-gold text-ink flex items-center justify-center font-black text-xs shrink-0 shadow-sm">
                  1
                </div>
                <div className="space-y-0.5">
                  <p className="text-xs font-bold text-ink-fg">Share Link or QR Code</p>
                  <p className="text-xs text-ink-muted font-medium leading-relaxed">
                    Send your personalized invite link or QR badge to friends, groups, or social
                    followers.
                  </p>
                </div>
              </div>

              <div className="flex gap-3.5 items-start">
                <div className="size-7 rounded-xl bg-gold text-ink flex items-center justify-center font-black text-xs shrink-0 shadow-sm">
                  2
                </div>
                <div className="space-y-0.5">
                  <p className="text-xs font-bold text-ink-fg">Friends Join & Get 50 PTS</p>
                  <p className="text-xs text-ink-muted font-medium leading-relaxed">
                    They sign up with zero fees and receive an immediate 50 PTS starter reward in
                    their vault.
                  </p>
                </div>
              </div>

              <div className="flex gap-3.5 items-start">
                <div className="size-7 rounded-xl bg-emerald-500 text-white flex items-center justify-center font-black text-xs shrink-0 shadow-sm">
                  3
                </div>
                <div className="space-y-0.5">
                  <p className="text-xs font-bold text-ink-fg">You Collect 75 PTS Commission</p>
                  <p className="text-xs text-ink-muted font-medium leading-relaxed">
                    As soon as they complete their profile & first task, 75 PTS are credited
                    instantly to your account.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Referral Pro Tips */}
          <div className="rounded-3xl p-6 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl space-y-4">
            <div className="flex items-center gap-2">
              <Lightbulb className="size-4 text-gold" />
              <h3 className="font-black text-sm text-ink-fg">Pro Tips to Maximize Invites</h3>
            </div>

            <ul className="space-y-2.5 text-xs text-ink-muted font-medium">
              <li className="flex items-start gap-2">
                <CheckCircle2 className="size-3.5 text-gold shrink-0 mt-0.5" />
                <span>
                  Share your link in active Discord, Telegram, or WhatsApp reward communities.
                </span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle2 className="size-3.5 text-gold shrink-0 mt-0.5" />
                <span>Explain how easy it is to claim real gift cards on Noble Gain.</span>
              </li>
              <li className="flex items-start gap-2">
                <CheckCircle2 className="size-3.5 text-gold shrink-0 mt-0.5" />
                <span>Use the QR code feature for in-person sharing on mobile.</span>
              </li>
            </ul>
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}

export default ReferralPage;
