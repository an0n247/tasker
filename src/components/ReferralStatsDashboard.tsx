import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  Users,
  MousePointerClick,
  Gift,
  TrendingUp,
  Copy,
  Check,
  Share2,
  ExternalLink,
  ArrowRight,
  ShieldCheck,
  QrCode,
  Sparkles,
  Coins,
  Crown,
  Send,
  Target,
  MessageCircle,
  Link2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { useState, useEffect } from "react";
import { toast } from "sonner";
import { QRCodeCanvas } from "qrcode.react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";

export function ReferralStatsDashboard() {
  const [copiedLink, setCopiedLink] = useState(false);
  const [copiedCode, setCopiedCode] = useState(false);
  const queryClient = useQueryClient();

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

  useEffect(() => {
    if (!profile?.id) return;

    const channel = supabase
      .channel("referral-stats-realtime")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "referrals",
          filter: `referrer_id=eq.${profile.id}`,
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["referrals-stats", profile.id] });
          queryClient.invalidateQueries({ queryKey: ["referrals", profile.id] });
          queryClient.invalidateQueries({ queryKey: ["profile"] });
          toast.success("New referral update received!");
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [profile?.id, queryClient]);

  const { data: referralsStats } = useQuery({
    queryKey: ["referrals-stats", profile?.id],
    queryFn: async () => {
      if (!profile?.id) return { total_referrals: 0, points_earned: 0 };
      const { data, error } = await supabase
        .from("referral_stats_summary")
        .select("*")
        .eq("user_id", profile.id)
        .maybeSingle();

      if (error) throw error;
      return data || { total_referrals: 0, points_earned: 0 };
    },
    enabled: !!profile?.id,
  });

  const referralCode = profile?.referral_code || profile?.id?.slice(0, 8) || "";
  const referralLink =
    typeof window !== "undefined"
      ? `${window.location.origin}/auth?ref=${referralCode}&mode=signup`
      : `/auth?ref=${referralCode}&mode=signup`;

  const copyLink = () => {
    if (!referralLink) return;
    const referralNote = `🚀 Join me on Noble Gain and start earning real rewards and cash for completing quick daily tasks! Sign up with my invite link to get a 50 PTS welcome bonus:\n\n${referralLink}\n\nInvite Code: ${referralCode}`;
    navigator.clipboard.writeText(referralNote);
    setCopiedLink(true);
    toast.success("Invite message & link copied to clipboard!");
    setTimeout(() => setCopiedLink(false), 2500);
  };

  const copyCode = () => {
    if (!referralCode) return;
    navigator.clipboard.writeText(referralCode);
    setCopiedCode(true);
    toast.success("Referral code copied!");
    setTimeout(() => setCopiedCode(false), 2500);
  };

  const count = referralsStats?.total_referrals || 0;
  const pointsEarned = referralsStats?.points_earned || 0;
  const linkClicks = profile?.referral_clicks || 0;
  const convRate = linkClicks ? Math.min(100, Math.round((count / linkClicks) * 100)) : 0;

  // Multi-tier milestone goals
  const getMilestoneInfo = (totalRefs: number) => {
    if (totalRefs >= 50)
      return {
        title: "Elite Ambassador",
        target: 100,
        bonus: 1000,
        level: "Tier 3",
        progress: Math.min(100, (totalRefs / 100) * 100),
      };
    if (totalRefs >= 10)
      return {
        title: "Super Referrer",
        target: 50,
        bonus: 500,
        level: "Tier 2",
        progress: Math.min(100, (totalRefs / 50) * 100),
      };
    return {
      title: "Network Pioneer",
      target: 10,
      bonus: 200,
      level: "Tier 1",
      progress: Math.min(100, (totalRefs / 10) * 100),
    };
  };

  const milestone = getMilestoneInfo(count);

  return (
    <div className="space-y-6">
      {/* 4 Bento Metric Cards */}
      <div className="grid gap-4 grid-cols-2 lg:grid-cols-4">
        {/* Card 1: Link Clicks */}
        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Link Clicks
            </span>
            <div className="size-9 rounded-2xl bg-blue-500/15 text-blue-400 flex items-center justify-center border border-blue-500/25">
              <MousePointerClick className="size-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-ink-fg">
            {linkClicks.toLocaleString()}
          </p>
          <p className="text-[11px] font-medium text-ink-muted mt-1">Unique visits logged</p>
        </div>

        {/* Card 2: Total Referrals */}
        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Active Invites
            </span>
            <div className="size-9 rounded-2xl bg-gold/15 text-gold flex items-center justify-center border border-gold/25">
              <Users className="size-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-ink-fg">
            {count.toLocaleString()}
          </p>
          <p className="text-[11px] font-medium text-ink-muted mt-1">Joined via your link</p>
        </div>

        {/* Card 3: Points Earned */}
        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Points Earned
            </span>
            <div className="size-9 rounded-2xl bg-emerald-500/15 text-emerald-400 flex items-center justify-center border border-emerald-500/25">
              <Gift className="size-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-ink-fg">
            {pointsEarned.toLocaleString()} <span className="text-xs font-bold text-gold">PTS</span>
          </p>
          <p className="text-[11px] font-medium text-ink-muted mt-1">
            +75 PTS per qualified referee
          </p>
        </div>

        {/* Card 4: Conversion Rate */}
        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Conv. Rate
            </span>
            <div className="size-9 rounded-2xl bg-amber-500/15 text-amber-400 flex items-center justify-center border border-amber-500/25">
              <TrendingUp className="size-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-black font-mono tracking-tight text-ink-fg">
            {convRate}%
          </p>
          <p className="text-[11px] font-medium text-ink-muted mt-1">Click-to-signup efficiency</p>
        </div>
      </div>

      {/* Luxury Referral Share Hub */}
      <div className="rounded-[2rem] p-6 sm:p-8 bg-gradient-to-br from-[#002d26] via-[#003830] to-[#011e19] text-white shadow-xl border border-gold/25 relative overflow-hidden space-y-6">
        {/* Ambient Spheres */}
        <div className="absolute top-0 right-0 size-72 bg-gold/15 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 size-64 bg-emerald-500/15 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 border border-white/15 text-xs font-bold text-gold backdrop-blur-md">
            <Sparkles className="size-3.5 text-gold" />
            <span>Dual Earning Guarantee</span>
          </div>
          <h2 className="text-2xl sm:text-3xl font-black tracking-tight text-white">
            Your Personal Invitation Hub
          </h2>
          <p className="text-xs sm:text-sm font-medium text-white/80 max-w-xl leading-relaxed">
            Share your invite link with friends. You receive{" "}
            <strong className="text-gold font-bold">75 points</strong> for each qualified member,
            and they get an instant <strong className="text-gold font-bold">50 points</strong>{" "}
            welcome bonus!
          </p>
        </div>

        <div className="relative z-10 grid gap-5 md:grid-cols-2">
          {/* Referral Link Copy Field */}
          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-white/70">
              Referral Invite Link
            </label>
            <div className="flex items-center gap-2 p-1.5 bg-black/40 border border-white/15 rounded-2xl backdrop-blur-md">
              <input
                readOnly
                value={referralLink}
                className="bg-transparent flex-1 px-3 font-mono text-xs text-white/90 outline-none truncate"
              />
              <Button
                onClick={copyLink}
                className="h-10 rounded-xl px-4 font-bold bg-gold text-ink hover:bg-gold-soft border-none shadow-sm text-xs shrink-0 transition-transform active:scale-95 cursor-pointer"
              >
                {copiedLink ? (
                  <Check className="size-4 mr-1 text-ink" />
                ) : (
                  <Copy className="size-4 mr-1" />
                )}
                <span>{copiedLink ? "Copied!" : "Copy Link"}</span>
              </Button>
            </div>
          </div>

          {/* Referral Code Only */}
          <div className="space-y-2">
            <label className="text-[11px] font-bold uppercase tracking-wider text-white/70">
              Referral Code
            </label>
            <div className="flex items-center gap-2 p-1.5 bg-black/40 border border-white/15 rounded-2xl backdrop-blur-md">
              <input
                readOnly
                value={referralCode}
                className="bg-transparent flex-1 px-3 font-mono text-xs font-bold text-gold tracking-widest outline-none uppercase"
              />
              <Button
                onClick={copyCode}
                variant="outline"
                className="h-10 rounded-xl px-4 font-bold bg-white/10 border-white/20 text-white hover:bg-white/20 text-xs shrink-0 transition-transform active:scale-95 cursor-pointer"
              >
                {copiedCode ? (
                  <Check className="size-4 mr-1 text-emerald-400" />
                ) : (
                  <Copy className="size-4 mr-1" />
                )}
                <span>{copiedCode ? "Copied Code" : "Copy Code"}</span>
              </Button>
            </div>
          </div>
        </div>

        {/* Quick Social Sharing Bar */}
        <div className="relative z-10 pt-4 border-t border-white/10 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-2 text-xs font-bold text-white/80">
            <span>Instant Share:</span>
          </div>

          <div className="flex flex-wrap items-center gap-2.5">
            {/* QR Code Dialog */}
            <Dialog>
              <DialogTrigger asChild>
                <Button
                  variant="outline"
                  className="h-10 rounded-xl px-3.5 bg-white/10 border-white/20 text-white hover:bg-white/20 text-xs font-bold flex items-center gap-2 cursor-pointer"
                >
                  <QrCode className="size-4 text-gold" />
                  <span>Show QR Code</span>
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-md rounded-3xl bg-ink-2 border border-hairline text-ink-fg">
                <DialogHeader>
                  <DialogTitle className="text-center text-xl font-black text-ink-fg">
                    Scan to Join
                  </DialogTitle>
                  <DialogDescription className="text-center text-xs font-medium text-ink-muted">
                    Friends can scan this QR code directly with their mobile camera to join your
                    network.
                  </DialogDescription>
                </DialogHeader>
                <div className="flex flex-col items-center justify-center p-6 space-y-4">
                  <div className="p-4 bg-white rounded-3xl shadow-lg border border-hairline">
                    <QRCodeCanvas value={referralLink} size={210} level="H" includeMargin={true} />
                  </div>
                  <div className="text-center space-y-1">
                    <p className="text-sm font-black text-gold font-mono tracking-widest uppercase">
                      {referralCode}
                    </p>
                    <p className="text-xs text-ink-muted font-bold">Your Referral Code</p>
                  </div>
                </div>
              </DialogContent>
            </Dialog>

            {/* X / Twitter Intent */}
            <Button
              variant="outline"
              className="h-10 rounded-xl px-3.5 bg-white/10 border-white/20 text-white hover:bg-white/20 text-xs font-bold cursor-pointer"
              onClick={() =>
                window.open(
                  `https://twitter.com/intent/tweet?text=Join%20me%20on%20Noble%20Gain%20and%20turn%20your%20digital%20activity%20into%20real%20rewards!%20Get%20a%2050%20PTS%20welcome%20bonus%20here:%20${encodeURIComponent(referralLink)}`,
                  "_blank",
                )
              }
            >
              <Share2 className="size-4 mr-1.5 text-sky-400" />
              <span>Post to X</span>
            </Button>

            {/* WhatsApp Intent */}
            <Button
              variant="outline"
              className="h-10 rounded-xl px-3.5 bg-white/10 border-white/20 text-white hover:bg-white/20 text-xs font-bold cursor-pointer"
              onClick={() =>
                window.open(
                  `https://wa.me/?text=Join%20me%20on%20Noble%20Gain%20and%20start%20earning%20rewards%20with%20me!%20Use%20my%20link%20for%20a%20free%20welcome%20bonus:%20${encodeURIComponent(referralLink)}`,
                  "_blank",
                )
              }
            >
              <MessageCircle className="size-4 mr-1.5 text-emerald-400" />
              <span>WhatsApp</span>
            </Button>

            {/* Telegram Intent */}
            <Button
              variant="outline"
              className="h-10 rounded-xl px-3.5 bg-white/10 border-white/20 text-white hover:bg-white/20 text-xs font-bold cursor-pointer"
              onClick={() =>
                window.open(
                  `https://t.me/share/url?url=${encodeURIComponent(referralLink)}&text=Join%20me%20on%20Noble%20Gain%20and%20claim%20your%2050%20PTS%20bonus!`,
                  "_blank",
                )
              }
            >
              <Send className="size-4 mr-1.5 text-blue-400" />
              <span>Telegram</span>
            </Button>
          </div>
        </div>
      </div>

      {/* Referral Milestone & Tier Multiplier Progression */}
      <div className="rounded-3xl p-6 sm:p-7 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl space-y-5">
        <div className="flex items-center justify-between">
          <div className="space-y-0.5">
            <h3 className="font-black text-base text-ink-fg flex items-center gap-2">
              <Crown className="size-4 text-gold" />
              Network Milestone Progress
            </h3>
            <p className="text-xs text-ink-muted font-medium">
              Achieve invitation targets to unlock exclusive milestone point bonuses.
            </p>
          </div>
          <span className="bg-gold/15 text-gold border border-gold/30 font-black text-xs px-3 py-1 rounded-xl">
            {milestone.level}
          </span>
        </div>

        <div className="space-y-2">
          <div className="flex justify-between text-xs font-bold text-ink-muted">
            <span>Next Goal: {milestone.title}</span>
            <span className="font-mono text-ink-fg">
              {count} / {milestone.target} Invites ({Math.round(milestone.progress)}%)
            </span>
          </div>
          <div className="h-2.5 bg-ink-3 rounded-full overflow-hidden border border-hairline">
            <div
              className="h-full bg-gradient-to-r from-gold to-emerald-400 rounded-full transition-all duration-500"
              style={{ width: `${milestone.progress}%` }}
            />
          </div>
        </div>

        <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-start gap-3.5">
          <div className="p-2 rounded-xl bg-gold text-ink shrink-0 shadow-sm font-bold">
            <ShieldCheck className="size-4 text-ink" />
          </div>
          <div className="space-y-0.5">
            <p className="text-xs font-bold text-ink-fg">
              Unlock {milestone.title} Status (+{milestone.bonus} PTS Bonus)
            </p>
            <p className="text-xs text-ink-muted font-medium">
              Invite {Math.max(0, milestone.target - count)} more active members to automatically
              claim your {milestone.bonus} points milestone reward!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
