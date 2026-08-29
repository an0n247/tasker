import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Gift, Sparkles, Coins, Loader2, CheckCircle2, XCircle } from "lucide-react";
import { toast } from "sonner";
import confetti from "canvas-confetti";
import { useQueryClient } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";

export function WelcomeBonusModal() {
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [profile, setProfile] = useState<any>(null);
  const [bonusAmount, setBonusAmount] = useState(50);
  const [referrerName, setReferrerName] = useState<string | null>(null);
  const [requiredSocials, setRequiredSocials] = useState<string[]>([]);
  const queryClient = useQueryClient();

  useEffect(() => {
    checkEligibility();

    // Subscribe to profile changes for real-time eligibility updates
    const subscribeToProfile = async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const channel = supabase
        .channel(`profile-verification-${user.id}`)
        .on(
          "postgres_changes",
          {
            event: "UPDATE",
            schema: "public",
            table: "profiles",
            filter: `id=eq.${user.id}`,
          },
          (payload) => {
            const newProfile = payload.new as any;
            setProfile(newProfile);

            // If the user was ineligible due to missing social handles but now has them,
            // we should re-check eligibility if the modal wasn't already dismissed
            if (
              !newProfile.has_claimed_welcome_bonus &&
              !newProfile.welcome_banner_dismissed &&
              newProfile.referred_by
            ) {
              // We check if it's already open, if not, checkEligibility will evaluate logic
              if (!isOpen) {
                checkEligibility();
              }
            }
          },
        )
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
      };
    };

    const unsubscribePromise = subscribeToProfile();
    return () => {
      unsubscribePromise.then((unsubscribe) => unsubscribe?.());
    };
  }, [isOpen]);

  const checkEligibility = async () => {
    try {
      // Check session storage first for immediate one-time display enforcement per session
      const hasShownThisSession = sessionStorage.getItem("welcome_bonus_shown");
      if (hasShownThisSession) return;

      // Fetch welcome bonus settings
      const { data: settings } = await (supabase.from("app_settings" as any) as any)
        .select("*")
        .in("key", [
          "welcome_bonus_enabled",
          "welcome_bonus_amount_referee",
          "welcome_bonus_required_socials",
        ]);

      const isEnabled =
        settings?.find((s: any) => s.key === "welcome_bonus_enabled")?.value === true;
      const amount =
        settings?.find((s: any) => s.key === "welcome_bonus_amount_referee")?.value || 50;
      const required =
        settings?.find((s: any) => s.key === "welcome_bonus_required_socials")?.value || [];

      setBonusAmount(amount);
      setRequiredSocials(required);
      if (!isEnabled) return;

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      // Check localStorage for this specific user
      const hasSeen = localStorage.getItem(`welcome_bonus_dismissed_${user.id}`);
      if (hasSeen === "true") return;

      const { data: profileData } = await supabase
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
        .single();

      if (
        profileData &&
        profileData.referred_by &&
        !profileData.has_claimed_welcome_bonus &&
        !profileData.welcome_banner_dismissed
      ) {
        setProfile(profileData);
        const referrer = profileData.referrer as any;
        const refName = referrer?.full_name || referrer?.username || null;
        setReferrerName(refName);
        setIsOpen(true);
        sessionStorage.setItem("welcome_bonus_shown", "true");
      }
    } catch (error) {
      console.error("Error checking welcome bonus eligibility:", error);
    }
  };

  const handleClaim = async () => {
    setLoading(true);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase.rpc("claim_welcome_bonus", {
        _user_id: user.id,
      });

      const result = data as any;

      if (error || !result.success) {
        throw new Error(result?.message || error?.message || "Failed to claim bonus");
      }

      // Success!
      confetti({
        particleCount: 150,
        spread: 70,
        origin: { y: 0.6 },
        colors: ["#7c3aed", "#10b981", "#fbbf24"],
      });

      toast.success(`Welcome bonus claimed! +${bonusAmount} points`);
      // Use any cast to bypass type errors until types are regenerated
      (supabase.from("analytics_events" as any) as any)
        .insert({
          user_id: user.id,
          event_name: "welcome_bonus_claimed",
          metadata: { amount: bonusAmount },
        })
        .then();

      // Mark as dismissed in localStorage immediately
      localStorage.setItem(`welcome_bonus_dismissed_${user.id}`, "true");
      setIsOpen(false);

      // Invalidate queries to update balance
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["recentTransactions"] });
    } catch (error: any) {
      if (error.message.includes("complete your social profiles")) {
        toast.error(error.message, {
          action: {
            label: "Go to Profile",
            onClick: () => (window.location.href = "/profile"),
          },
        });
      } else {
        toast.error(error.message);
      }
    } finally {
      setLoading(false);
    }
  };

  const handleClose = async () => {
    setIsOpen(false);
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        // Mark in localStorage first for immediate effect
        localStorage.setItem(`welcome_bonus_dismissed_${user.id}`, "true");

        await supabase
          .from("profiles")
          .update({ welcome_banner_dismissed: true } as any)
          .eq("id", user.id);

        // Update local query cache
        queryClient.invalidateQueries({ queryKey: ["profile"] });
      }
    } catch (error) {
      console.error("Error dismissing welcome banner:", error);
    }
  };

  if (!isOpen) return null;

  return (
    <Dialog open={isOpen} onOpenChange={handleClose}>
      <DialogContent className="w-[calc(100%-1.5rem)] sm:max-w-md rounded-[1.5rem] md:rounded-[2rem] border-none shadow-2xl p-0 overflow-hidden bg-card mx-auto max-h-[90dvh] flex flex-col">
        <div className="relative h-20 md:h-32 bg-primary flex items-center justify-center overflow-hidden shrink-0">
          <Sparkles className="absolute top-3 left-3 h-4 w-4 md:h-6 md:w-6 text-white/20 animate-pulse" />
          <Sparkles className="absolute bottom-3 right-6 h-3 w-3 md:h-4 md:w-4 text-white/30 animate-bounce" />
          <div className="bg-white/20 p-2 md:p-4 rounded-2xl md:rounded-3xl backdrop-blur-sm relative z-10 border border-white/20">
            <img
              src="/logo.png"
              alt="Noble Gain"
              className="h-8 w-8 md:h-12 md:w-12 object-contain"
            />
          </div>
          {/* Decorative shapes */}
          <div className="absolute -top-10 -right-10 w-24 h-24 md:w-32 md:h-32 bg-white/10 rounded-full blur-xl md:blur-2xl" />
          <div className="absolute -bottom-6 -left-6 w-16 h-16 md:w-24 md:h-24 bg-black/10 rounded-full blur-lg md:blur-xl" />
        </div>

        <div className="p-5 md:p-8 text-center space-y-4 md:space-y-6 overflow-y-auto flex-1 custom-scrollbar">
          <DialogHeader className="space-y-1">
            <DialogTitle className="text-lg md:text-2xl font-black tracking-tight text-foreground uppercase">
              Welcome Bonus!
            </DialogTitle>
            <DialogDescription className="text-xs md:text-base font-medium text-muted-foreground pt-0.5 md:pt-2">
              {referrerName ? (
                <>
                  Thanks for joining Noble Gain via{" "}
                  <span className="text-primary font-bold">{referrerName}'s</span> referral! You've
                  unlocked a special welcome gift.
                </>
              ) : (
                <>
                  Welcome to Noble Gain! You've unlocked a special welcome gift for joining our
                  community.
                </>
              )}
            </DialogDescription>
          </DialogHeader>

          <div className="bg-primary/5 rounded-2xl p-3 md:p-6 flex flex-col items-center justify-center border border-primary/10 gap-0.5 md:gap-2 transition-transform duration-500 hover:scale-105">
            <div className="text-2xl md:text-4xl font-black text-primary tracking-tighter flex items-center gap-1.5 md:gap-2">
              <Coins className="h-5 w-5 md:h-8 md:w-8" />
              {bonusAmount}
              <span className="text-[10px] md:text-sm opacity-60 font-black uppercase tracking-widest ml-0.5 md:ml-1">
                Points
              </span>
            </div>
            <p className="text-[8px] md:text-[10px] font-black uppercase tracking-[0.2em] text-primary/60">
              Ready to claim
            </p>
          </div>

          {requiredSocials.length > 0 && (
            <div className="space-y-3 pt-2">
              <p className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                Required Verification
              </p>
              <div className="grid grid-cols-1 gap-2">
                {requiredSocials.map((social) => {
                  const handleKey = `${social}_handle`;
                  const isVerified = profile?.[handleKey] && profile[handleKey].length > 0;
                  return (
                    <div
                      key={social}
                      className={`flex items-center justify-between p-3 rounded-xl border transition-colors ${
                        isVerified
                          ? "bg-emerald-500/5 border-emerald-500/20"
                          : "bg-destructive/5 border-destructive/20"
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        {isVerified ? (
                          <CheckCircle2 className="h-4 w-4 text-emerald-500" />
                        ) : (
                          <XCircle className="h-4 w-4 text-destructive" />
                        )}
                        <span
                          className={`text-xs font-bold capitalize ${isVerified ? "text-emerald-600" : "text-destructive"}`}
                        >
                          {social} Handle
                        </span>
                      </div>
                      {!isVerified && (
                        <Link
                          to="/profile"
                          className="text-[10px] font-black uppercase tracking-tighter text-destructive hover:underline"
                        >
                          Add Now
                        </Link>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          <DialogFooter className="sm:justify-center pt-0.5 md:pt-2">
            <Button
              onClick={handleClaim}
              disabled={loading}
              className="w-full h-11 md:h-14 rounded-xl md:rounded-2xl text-sm md:text-lg font-black uppercase tracking-tight shadow-lg shadow-primary/20 hover:scale-[1.02] active:scale-[0.98] transition-all"
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 md:h-5 md:w-5 animate-spin" />
                  Claiming...
                </>
              ) : (
                "Claim My Bonus"
              )}
            </Button>
          </DialogFooter>

          <button
            onClick={handleClose}
            className="text-[8px] md:text-[10px] font-black uppercase tracking-widest text-muted-foreground hover:text-foreground transition-colors pb-2"
          >
            Claim later
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
