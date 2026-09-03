import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import {
  Sparkles,
  Coins,
  CheckCircle2,
  ArrowRight,
  Flame,
  Users,
  Award,
  Zap,
  Gift,
} from "lucide-react";
import confetti from "canvas-confetti";
import { useQueryClient } from "@tanstack/react-query";
import { Link, useRouter } from "@tanstack/react-router";
import { motion, AnimatePresence } from "framer-motion";

export function WelcomeBonusModal() {
  const [isOpen, setIsOpen] = useState(false);
  const [profile, setProfile] = useState<any>(null);
  const [bonusAmount, setBonusAmount] = useState(50);
  const [referrerName, setReferrerName] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const router = useRouter();

  useEffect(() => {
    let isMounted = true;

    const evaluateFirstLoginWelcome = async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (!user || !isMounted) return;

        const storageKey = `noble_gain_welcome_seen_${user.id}`;
        const hasSeenLocal = localStorage.getItem(storageKey);
        if (hasSeenLocal === "true") return;

        // Fetch profile and settings in parallel
        const [{ data: profileData }, { data: settings }] = await Promise.all([
          supabase
            .from("profiles")
            .select(
              `
              *,
              referrer:referred_by (
                full_name,
                username
              )
            `,
            )
            .eq("id", user.id)
            .maybeSingle(),
          supabase
            .from("app_settings" as any)
            .select("*")
            .eq("key", "welcome_bonus_amount_referee")
            .maybeSingle(),
        ]);

        if (!profileData || !isMounted) return;

        const configuredBonus =
          (settings as any)?.value && typeof (settings as any).value === "number"
            ? (settings as any).value
            : 50;
        setBonusAmount(configuredBonus);

        // Only show if user has not already dismissed the welcome banner
        if (!profileData.welcome_banner_dismissed) {
          setProfile(profileData);
          const referrer = profileData.referrer as any;
          const refName = referrer?.full_name || referrer?.username || null;
          setReferrerName(refName);
          setIsOpen(true);

          // Mark local storage immediately so it will never show more than once in this browser
          localStorage.setItem(storageKey, "true");

          // Fire welcome confetti!
          setTimeout(() => {
            confetti({
              particleCount: 80,
              spread: 60,
              origin: { y: 0.5 },
              colors: ["#e6c17a", "#10b981", "#3b82f6", "#f59e0b"],
            });
          }, 300);
        }
      } catch (err) {
        console.error("Error displaying welcome modal:", err);
      }
    };

    evaluateFirstLoginWelcome();

    return () => {
      isMounted = false;
    };
  }, []);

  const handleDismissAndExplore = async () => {
    setIsOpen(false);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        localStorage.setItem(`noble_gain_welcome_seen_${user.id}`, "true");
        await supabase
          .from("profiles")
          .update({ welcome_banner_dismissed: true } as any)
          .eq("id", user.id);
        queryClient.invalidateQueries({ queryKey: ["profile"] });
      }
    } catch (err) {
      console.error("Error dismissing welcome banner:", err);
    }
  };

  if (!isOpen) return null;

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && handleDismissAndExplore()}>
      <DialogContent className="w-[92vw] max-w-lg p-0 overflow-hidden rounded-[2.5rem] border border-gold/30 bg-ink-2/95 text-ink-fg backdrop-blur-2xl shadow-2xl shadow-gold/10">
        {/* Top Ambient Glow / Header Banner */}
        <div className="relative pt-10 pb-8 px-6 bg-gradient-to-b from-gold/15 via-gold/5 to-transparent text-center overflow-hidden flex flex-col items-center">
          {/* Subtle Ambient Ring */}
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-64 h-32 bg-gold/20 rounded-full blur-3xl pointer-events-none" />

          {/* Logo / Badge with Animated Pulse */}
          <div className="relative mb-5">
            <div className="size-20 rounded-3xl bg-ink-3/90 border-2 border-gold/40 flex items-center justify-center shadow-xl shadow-gold/20 relative z-10 group">
              <img
                src="/logo.png"
                alt="Noble Gain"
                className="size-12 object-contain filter drop-shadow-[0_2px_8px_rgba(230,193,122,0.4)]"
              />
            </div>
            <div className="absolute -inset-2 bg-gradient-to-r from-gold/30 via-amber-400/20 to-gold/30 rounded-3xl blur-md animate-pulse" />
          </div>

          {/* Top Pill Badge */}
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-gold/15 border border-gold/30 text-gold text-[11px] font-black uppercase tracking-wider mb-2">
            <Sparkles className="size-3.5 animate-spin text-gold" />
            <span>Welcome to Noble Gain</span>
          </div>

          <DialogTitle className="text-2xl sm:text-3xl font-black text-ink-fg tracking-tight">
            You're In! Welcome, {profile?.username || profile?.full_name || "Partner"} 🌟
          </DialogTitle>

          <DialogDescription className="text-xs sm:text-sm text-ink-muted mt-2 max-w-sm font-medium leading-relaxed">
            {referrerName ? (
              <>
                You joined via{" "}
                <span className="text-gold font-bold">@{referrerName}'s</span> referral link. Your
                welcome bonus has been added to your vault!
              </>
            ) : (
              <>
                Your journey starts here. Your welcome bonus is active and credited to your vault
                balance!
              </>
            )}
          </DialogDescription>
        </div>

        {/* Bonus Highlight Card */}
        <div className="px-6 pb-8 space-y-6">
          <div className="relative p-5 rounded-3xl bg-ink/50 border border-gold/25 flex items-center justify-between shadow-inner overflow-hidden">
            <div className="absolute -right-6 -bottom-6 size-24 bg-gold/10 rounded-full blur-xl pointer-events-none" />
            
            <div className="flex items-center gap-3.5">
              <div className="size-12 rounded-2xl bg-gold/15 border border-gold/30 flex items-center justify-center shrink-0">
                <Gift className="size-6 text-gold" />
              </div>
              <div>
                <p className="text-[10px] font-black uppercase tracking-widest text-ink-muted">
                  Vault Bonus Credited
                </p>
                <h4 className="text-xl font-black text-ink-fg flex items-center gap-1.5">
                  +{bonusAmount} <span className="text-gold font-extrabold text-sm">PTS</span>
                </h4>
              </div>
            </div>

            <div className="px-3 py-1.5 rounded-xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 text-xs font-black flex items-center gap-1">
              <CheckCircle2 className="size-3.5" />
              <span>Active</span>
            </div>
          </div>

          {/* Quick Perks / Onboarding Highlights */}
          <div className="space-y-3">
            <p className="text-[10px] font-black uppercase tracking-widest text-ink-muted px-1">
              Ways to Earn & Win
            </p>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
              <div className="p-3 rounded-2xl bg-ink-3/40 border border-hairline/60 flex sm:flex-col items-center sm:items-start gap-3 sm:gap-2">
                <div className="size-8 rounded-xl bg-blue-500/15 border border-blue-500/30 flex items-center justify-center text-blue-400 shrink-0">
                  <Zap className="size-4" />
                </div>
                <div>
                  <p className="text-xs font-bold text-ink-fg">Daily Tasks</p>
                  <p className="text-[10px] text-ink-muted">Read & comment for 50 PTS each</p>
                </div>
              </div>

              <div className="p-3 rounded-2xl bg-ink-3/40 border border-hairline/60 flex sm:flex-col items-center sm:items-start gap-3 sm:gap-2">
                <div className="size-8 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-amber-400 shrink-0">
                  <Flame className="size-4" />
                </div>
                <div>
                  <p className="text-xs font-bold text-ink-fg">Daily Streaks</p>
                  <p className="text-[10px] text-ink-muted">Check in daily for multipliers</p>
                </div>
              </div>

              <div className="p-3 rounded-2xl bg-ink-3/40 border border-hairline/60 flex sm:flex-col items-center sm:items-start gap-3 sm:gap-2">
                <div className="size-8 rounded-xl bg-purple-500/15 border border-purple-500/30 flex items-center justify-center text-purple-400 shrink-0">
                  <Users className="size-4" />
                </div>
                <div>
                  <p className="text-xs font-bold text-ink-fg">Invite & Earn</p>
                  <p className="text-[10px] text-ink-muted">+75 PTS on their first task</p>
                </div>
              </div>
            </div>
          </div>

          {/* Action CTA Button */}
          <div className="space-y-3 pt-2">
            <Button
              asChild
              onClick={handleDismissAndExplore}
              className="w-full h-14 rounded-2xl font-black text-sm uppercase tracking-wider bg-gold text-ink hover:bg-gold-light transition-all duration-300 shadow-lg shadow-gold/25 hover:shadow-gold/40 hover:scale-[1.01] active:scale-[0.99] cursor-pointer"
            >
              <Link to="/earn">
                <span>Start Today's Tasks</span>
                <ArrowRight className="size-4 ml-2" />
              </Link>
            </Button>

            <button
              type="button"
              onClick={handleDismissAndExplore}
              className="w-full text-center text-[11px] font-bold text-ink-muted hover:text-ink-fg transition-colors py-1 cursor-pointer"
            >
              Go to Dashboard
            </button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
