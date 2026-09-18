import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Gift,
  Coins,
  ArrowRight,
  Wallet,
  History as HistoryIcon,
  Loader2,
  Sparkles,
  ShieldCheck,
  CheckCircle2,
  Filter,
  Mail,
  ClipboardPaste,
  AlertTriangle,
  Info,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useState } from "react";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import confetti from "canvas-confetti";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { motion } from "framer-motion";

export const Route = createFileRoute("/_authenticated/redeem")({
  head: () => ({
    title: "Redeem Rewards | Marketplace & Gift Cards | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Exchange your hard-earned Noble Gain points for cryptocurrency (USDT TRC20) and premium digital gift cards.",
      },
      { property: "og:title", content: "Redeem Points | Noble Gain Rewards" },
      {
        property: "og:description",
        content:
          "Turn your points into real-world rewards. Choose between instant crypto withdrawals and digital gift cards.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: RedeemPage,
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

function isRewardCrypto(reward: any): boolean {
  if (!reward) return false;
  const category = (reward.category || "").toLowerCase();
  const title = (reward.title || "").toLowerCase();
  return category.includes("crypto") || title.includes("crypto") || title.includes("usdt");
}

function RedeemPage() {
  const [activeCategory, setActiveCategory] = useState<"crypto" | "giftcard" | "All">("All");
  const [selectedReward, setSelectedReward] = useState<any>(null);
  const [walletAddress, setWalletAddress] = useState("");
  const [walletError, setWalletError] = useState("");
  const [isRedeeming, setIsRedeeming] = useState(false);
  const queryClient = useQueryClient();

  const { data: rewards, isLoading } = useQuery({
    queryKey: ["rewards"],
    queryFn: async () => {
      const { data } = await supabase
        .from("rewards")
        .select("*")
        .eq("is_active", true)
        .order("cost_points", { ascending: true })
        .order("title", { ascending: true });
      return (data || []).sort(
        (a: any, b: any) => Number(a.cost_points ?? 0) - Number(b.cost_points ?? 0),
      );
    },
  });

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

  const cryptoCount = rewards?.filter(isRewardCrypto).length || 0;
  const giftCardCount = rewards?.filter((r) => !isRewardCrypto(r)).length || 0;

  const categories = [
    {
      id: "All" as const,
      name: "All Rewards",
      badge: `${rewards?.length || 0}`,
      icon: Sparkles,
    },
    {
      id: "crypto" as const,
      name: "Crypto Rewards",
      badge: "USDT (TRC20)",
      icon: Coins,
    },
    {
      id: "giftcard" as const,
      name: "Gift Card Rewards",
      badge: "Email Delivery",
      icon: Gift,
    },
  ];

  const filteredRewards = (
    activeCategory === "All"
      ? rewards
      : activeCategory === "crypto"
        ? rewards?.filter(isRewardCrypto)
        : rewards?.filter((r: any) => !isRewardCrypto(r))
  )
    ?.slice()
    .sort((a: any, b: any) => Number(a.cost_points ?? 0) - Number(b.cost_points ?? 0));

  const userBalance = profile?.points_balance || 0;

  const handleOpenReward = (reward: any) => {
    setSelectedReward(reward);
    setWalletAddress("");
    setWalletError("");
  };

  const validateWalletAddress = (addr: string): boolean => {
    const trimmed = addr.trim();
    if (!trimmed) {
      setWalletError("USDT (TRC20) wallet address is required.");
      return false;
    }
    if (!trimmed.startsWith("T")) {
      setWalletError("TRC20 wallet addresses must begin with the letter 'T'.");
      return false;
    }
    if (trimmed.length < 25 || trimmed.length > 50) {
      setWalletError("Invalid TRC20 wallet length (expected 34 characters).");
      return false;
    }
    setWalletError("");
    return true;
  };

  const handlePasteAddress = async () => {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        setWalletAddress(text.trim());
        validateWalletAddress(text.trim());
        toast.success("Wallet address pasted!");
      }
    } catch {
      toast.error("Clipboard permission denied. Please paste manually.");
    }
  };

  const handleRedeem = async () => {
    if (!selectedReward || !profile) return;

    const isCrypto = isRewardCrypto(selectedReward);
    if (isCrypto) {
      const valid = validateWalletAddress(walletAddress);
      if (!valid) {
        toast.error("Please enter a valid USDT TRC20 wallet address.");
        return;
      }
    }

    setIsRedeeming(true);
    try {
      let result: { success: boolean; message: string; redemption_id?: string } | null = null;

      // 1. Attempt primary call with wallet address & delivery email
      const primaryRes = await supabase.rpc("redeem_reward" as any, {
        _reward_id: selectedReward.id,
        _wallet_address: isCrypto ? walletAddress.trim() : null,
        _delivery_email: !isCrypto ? profile.email : null,
      });

      if (primaryRes.error) {
        const errMsg = primaryRes.error.message || "";
        const isSchemaMismatch =
          errMsg.includes("schema cache") ||
          errMsg.includes("Could not find the function") ||
          (primaryRes.error as any).code === "PGRST202";

        if (isSchemaMismatch) {
          console.warn("RPC schema cache mismatch detected; retrying with single-argument fallback...");
          const fallbackRes = await supabase.rpc("redeem_reward" as any, {
            _reward_id: selectedReward.id,
          });

          if (fallbackRes.error) throw fallbackRes.error;
          result = fallbackRes.data as any;

          // If single-arg fallback succeeded, attempt to attach payout info directly if columns exist
          if (result?.success && result?.redemption_id) {
            try {
              await (supabase.from("redemptions") as any)
                .update({
                  wallet_address: isCrypto ? walletAddress.trim() : null,
                  delivery_email: !isCrypto ? profile.email : null,
                })
                .eq("id", result.redemption_id);
            } catch {
              // Gracefully ignore if columns not yet migrated
            }
          }
        } else {
          throw primaryRes.error;
        }
      } else {
        result = primaryRes.data as any;
      }

      if (!result?.success) {
        toast.error(result?.message || "Failed to redeem reward. Please try again.");
        return;
      }

      confetti({
        particleCount: 90,
        spread: 70,
        origin: { y: 0.6 },
      });

      if (isCrypto) {
        toast.success(
          "Crypto redemption submitted! Payout will be sent to your USDT TRC20 wallet upon approval.",
        );
      } else {
        toast.success(
          `Gift card request submitted! Digital voucher will be delivered to ${profile.email}.`,
        );
      }

      setSelectedReward(null);
      setWalletAddress("");
      setWalletError("");

      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["redemptions"] });
      queryClient.invalidateQueries({ queryKey: ["rewards"] });
    } catch (error: any) {
      console.error("Redemption error:", error);
      toast.error(error?.message || "Failed to redeem reward. Please try again.");
    } finally {
      setIsRedeeming(false);
    }
  };

  const isSelectedCrypto = selectedReward ? isRewardCrypto(selectedReward) : false;

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-7xl mx-auto pb-12"
    >
      {/* Background ambient light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header Banner */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Gift className="size-3.5" />
            <span>Rewards Bazaar</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Crypto & Gift Cards</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Redeem <span className="text-gold">Rewards</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Exchange your earned points for cryptocurrency (USDT TRC20) or verified digital gift
            cards.
          </p>
        </div>

        {/* Balance Vault & History Link */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <div className="rounded-2xl border border-hairline bg-ink-2/80 p-4 min-w-[220px] shadow-sm backdrop-blur-md flex items-center gap-3.5">
            <div className="size-11 rounded-xl bg-gold/15 border border-gold/30 text-gold flex items-center justify-center shrink-0">
              <Wallet className="size-5" />
            </div>
            <div>
              <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                Available Balance
              </p>
              <p className="text-xl font-black font-mono text-ink-fg">
                {userBalance.toLocaleString()} <span className="text-xs text-gold">PTS</span>
              </p>
            </div>
          </div>

          <Button
            asChild
            variant="outline"
            className="rounded-2xl h-auto py-3.5 px-4 border-hairline bg-ink-2/60 hover:bg-ink-3 text-xs font-bold text-ink-fg shrink-0 flex items-center gap-2 shadow-sm"
          >
            <Link to="/transactions">
              <HistoryIcon className="size-4 text-gold" />
              <span>Redemption History</span>
            </Link>
          </Button>
        </div>
      </motion.header>

      {/* Category Navigation Pills */}
      <motion.div
        variants={fadeInUp}
        className="flex gap-2 overflow-x-auto pb-1 scrollbar-none items-center"
      >
        <span className="text-xs font-bold uppercase tracking-wider text-ink-muted hidden sm:inline mr-1 flex items-center gap-1">
          <Filter className="size-3.5" /> Category:
        </span>
        {categories.map((cat) => {
          const isActive = activeCategory === cat.id;
          return (
            <button
              key={cat.id}
              type="button"
              onClick={() => setActiveCategory(cat.id)}
              className={cn(
                "rounded-xl font-bold h-11 px-4 text-xs shrink-0 transition-all flex items-center gap-2.5 border cursor-pointer",
                isActive
                  ? "bg-gold text-ink font-black border-gold shadow-md shadow-gold/10"
                  : "bg-ink-2/60 border-hairline text-ink-muted hover:text-ink-fg hover:bg-ink-3",
              )}
            >
              <cat.icon className={cn("size-4", isActive ? "text-ink" : "text-gold")} />
              <span>{cat.name}</span>
              <span
                className={cn(
                  "text-[10px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider",
                  isActive ? "bg-ink/20 text-ink" : "bg-ink-3 text-ink-muted border border-hairline",
                )}
              >
                {cat.badge}
              </span>
            </button>
          );
        })}
      </motion.div>

      {/* Rewards Grid */}
      <motion.div variants={fadeInUp} className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
        {filteredRewards?.length
          ? filteredRewards.map((reward) => {
              const canAfford = userBalance >= reward.cost_points;
              const pointsNeeded = Math.max(0, reward.cost_points - userBalance);
              const isCrypto = isRewardCrypto(reward);

              return (
                <div
                  key={reward.id}
                  className="rounded-3xl bg-ink-2/70 border border-hairline shadow-lg overflow-hidden flex flex-col justify-between group hover:border-gold/30 transition-all duration-300 backdrop-blur-xl"
                >
                  <div>
                    {/* Image Aspect Box */}
                    <div className="aspect-[16/9] bg-ink-3 relative overflow-hidden border-b border-hairline">
                      {reward.image_url ? (
                        <img
                          src={reward.image_url}
                          alt={reward.title}
                          className="object-cover w-full h-full transition-transform duration-500 group-hover:scale-105"
                        />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-ink-muted/30">
                          {isCrypto ? (
                            <Coins className="size-14 text-amber-400/40" />
                          ) : (
                            <Gift className="size-14 text-gold/30" />
                          )}
                        </div>
                      )}

                      {/* Floating Cost Pill */}
                      <div className="absolute top-3.5 right-3.5">
                        <div className="bg-ink/90 backdrop-blur-md text-gold border border-gold/30 shadow-md font-mono font-black text-xs rounded-xl px-3 py-1 flex items-center gap-1.5">
                          <Coins className="size-3.5 text-gold" />
                          <span>{reward.cost_points.toLocaleString()} PTS</span>
                        </div>
                      </div>

                      {/* Category Chip */}
                      <div className="absolute bottom-3.5 left-3.5">
                        <span
                          className={cn(
                            "backdrop-blur-md font-bold uppercase text-[10px] tracking-wider rounded-lg px-2.5 py-1 flex items-center gap-1.5 border",
                            isCrypto
                              ? "bg-ink/90 text-amber-400 border-amber-500/30"
                              : "bg-ink/90 text-gold border-gold/30",
                          )}
                        >
                          {isCrypto ? (
                            <Coins className="size-3 text-amber-400" />
                          ) : (
                            <Gift className="size-3 text-gold" />
                          )}
                          <span>{isCrypto ? "Crypto (USDT TRC20)" : "Gift Card"}</span>
                        </span>
                      </div>
                    </div>

                    {/* Info Content */}
                    <div className="p-6 space-y-2">
                      <h3 className="text-lg font-black text-ink-fg group-hover:text-gold transition-colors line-clamp-1">
                        {reward.title}
                      </h3>
                      <p className="text-xs font-medium text-ink-muted line-clamp-2 leading-relaxed">
                        {reward.description ||
                          (isCrypto
                            ? "Crypto payout sent to your TRC20 wallet upon security review."
                            : "Digital voucher delivered directly to your registered email address.")}
                      </p>
                    </div>
                  </div>

                  {/* Action Button Area */}
                  <div className="p-6 pt-0">
                    <Button
                      className={cn(
                        "w-full rounded-xl font-bold h-11 text-xs transition-all shadow-md cursor-pointer",
                        canAfford
                          ? isCrypto
                            ? "bg-amber-500 text-ink hover:bg-amber-400 font-black shadow-amber-500/10"
                            : "bg-gold text-ink hover:bg-gold-soft font-black shadow-gold/10"
                          : "bg-ink-3 text-ink-muted border border-hairline hover:bg-ink-3/80 shadow-none cursor-not-allowed",
                      )}
                      disabled={!canAfford}
                      onClick={() => handleOpenReward(reward)}
                    >
                      {canAfford ? (
                        <span className="flex items-center gap-1.5">
                          {isCrypto ? (
                            <>
                              <Coins className="size-3.5" />
                              <span>Withdraw Crypto</span>
                            </>
                          ) : (
                            <>
                              <Gift className="size-3.5" />
                              <span>Redeem Gift Card</span>
                            </>
                          )}
                          <ArrowRight className="size-3.5" />
                        </span>
                      ) : (
                        <span>Need {pointsNeeded.toLocaleString()} more PTS</span>
                      )}
                    </Button>
                  </div>
                </div>
              );
            })
          : !isLoading && (
              <div className="col-span-full rounded-3xl border border-hairline bg-ink-2/60 p-16 text-center space-y-4 backdrop-blur-xl">
                <div className="size-16 rounded-2xl bg-ink-3 text-gold flex items-center justify-center mx-auto border border-hairline shadow-inner">
                  {activeCategory === "crypto" ? (
                    <Coins className="size-8 text-amber-400" />
                  ) : (
                    <Gift className="size-8 text-gold" />
                  )}
                </div>
                <div className="space-y-1.5 max-w-sm mx-auto">
                  <h3 className="font-black text-lg text-ink-fg">
                    {activeCategory === "crypto"
                      ? "No crypto rewards available"
                      : activeCategory === "giftcard"
                        ? "No gift cards available"
                        : "No rewards found"}
                  </h3>
                  <p className="text-xs text-ink-muted font-medium">
                    No items are currently listed in this category. Check back soon as new stock is
                    added regularly.
                  </p>
                </div>
                {activeCategory !== "All" && (
                  <Button
                    onClick={() => setActiveCategory("All")}
                    className="rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft px-5 cursor-pointer"
                  >
                    View All Rewards
                  </Button>
                )}
              </div>
            )}

        {isLoading &&
          Array.from({ length: 6 }).map((_, i) => (
            <div
              key={i}
              className="rounded-3xl border border-hairline bg-ink-2/40 overflow-hidden h-[340px] animate-pulse space-y-4"
            >
              <div className="aspect-[16/9] bg-ink-3 w-full" />
              <div className="p-6 space-y-3">
                <div className="h-5 w-24 bg-ink-3 rounded-lg" />
                <div className="h-4 w-full bg-ink-3 rounded-lg" />
                <div className="h-11 w-full bg-ink-3 rounded-xl mt-6" />
              </div>
            </div>
          ))}
      </motion.div>

      {/* Confirmation & Details Modal */}
      <Dialog open={!!selectedReward} onOpenChange={(open) => !open && setSelectedReward(null)}>
        <DialogContent className="rounded-3xl max-w-md bg-ink-2 border border-hairline text-ink-fg p-6 sm:p-7 shadow-2xl backdrop-blur-2xl">
          <DialogHeader className="space-y-2">
            <div
              className={cn(
                "size-12 rounded-2xl border flex items-center justify-center mb-1",
                isSelectedCrypto
                  ? "bg-amber-500/15 border-amber-500/30 text-amber-400"
                  : "bg-gold/15 border-gold/30 text-gold",
              )}
            >
              {isSelectedCrypto ? <Coins className="size-6" /> : <Gift className="size-6" />}
            </div>
            <DialogTitle className="text-xl font-black tracking-tight text-ink-fg">
              {isSelectedCrypto ? "Withdraw Crypto (USDT TRC20)" : "Redeem Gift Card Reward"}
            </DialogTitle>
            <DialogDescription className="text-xs text-ink-muted leading-relaxed font-medium">
              {isSelectedCrypto
                ? "Enter your USDT TRC20 destination wallet address below to receive your payout."
                : "Your digital voucher will be delivered directly to your registered email address."}
            </DialogDescription>
          </DialogHeader>

          {selectedReward && (
            <div className="py-4 space-y-4">
              {/* Item Card Preview */}
              <div className="rounded-2xl p-4 bg-ink border border-hairline space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-ink-fg">{selectedReward.title}</span>
                  <span
                    className={cn(
                      "text-xs font-black font-mono px-2.5 py-1 rounded-lg border",
                      isSelectedCrypto
                        ? "text-amber-400 bg-amber-500/10 border-amber-500/25"
                        : "text-gold bg-gold/10 border-gold/25",
                    )}
                  >
                    {selectedReward.cost_points.toLocaleString()} PTS
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs text-ink-muted border-t border-hairline/60 pt-2.5">
                  <span>Balance after redemption:</span>
                  <span className="font-mono font-bold text-ink-fg">
                    {(userBalance - selectedReward.cost_points).toLocaleString()} PTS
                  </span>
                </div>
              </div>

              {/* Destination Section: Crypto vs Gift Card */}
              {isSelectedCrypto ? (
                <div className="space-y-3">
                  <div className="space-y-1.5">
                    <div className="flex items-center justify-between">
                      <label className="text-[11px] font-black uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                        <Coins className="size-3.5 text-amber-400" />
                        <span>USDT (TRC20) Wallet Address</span>
                      </label>
                      <button
                        type="button"
                        onClick={handlePasteAddress}
                        className="text-[11px] text-ink-muted hover:text-gold font-bold flex items-center gap-1 cursor-pointer transition-colors"
                      >
                        <ClipboardPaste className="size-3" />
                        <span>Paste</span>
                      </button>
                    </div>

                    <Input
                      type="text"
                      placeholder="e.g. TF1794wHG..."
                      value={walletAddress}
                      onChange={(e) => {
                        setWalletAddress(e.target.value);
                        if (walletError) validateWalletAddress(e.target.value);
                      }}
                      className={cn(
                        "h-12 rounded-xl font-mono text-xs bg-ink border-hairline focus:border-amber-500",
                        walletError && "border-destructive focus:border-destructive",
                      )}
                    />
                    {walletError && (
                      <p className="text-[11px] font-medium text-destructive flex items-center gap-1">
                        <AlertTriangle className="size-3 shrink-0" />
                        <span>{walletError}</span>
                      </p>
                    )}
                  </div>

                  {/* Warning Notice for TRC20 */}
                  <div className="rounded-2xl p-3 bg-amber-500/10 border border-amber-500/25 flex items-start gap-2.5 text-xs text-amber-400 font-medium leading-relaxed">
                    <AlertTriangle className="size-4 shrink-0 mt-0.5 text-amber-400" />
                    <span>
                      <strong className="font-bold">Tron (TRC20) Network Only:</strong> Please ensure
                      your address starts with <strong>T</strong>. Transfers to non-TRC20 networks
                      (such as ERC20 or BEP20) cannot be recovered.
                    </span>
                  </div>
                </div>
              ) : (
                <div className="space-y-3">
                  {/* Delivery email confirmation card */}
                  <div className="rounded-2xl p-4 bg-ink border border-hairline space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] font-black uppercase tracking-wider text-ink-muted flex items-center gap-1.5">
                        <Mail className="size-3.5 text-gold" />
                        <span>Delivery Destination</span>
                      </span>
                      <span className="text-[10px] font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-md border border-emerald-500/25 flex items-center gap-1">
                        <ShieldCheck className="size-3" /> Registered Email
                      </span>
                    </div>
                    <div className="p-3 rounded-xl bg-ink-2 border border-hairline/80 font-mono text-xs font-bold text-ink-fg flex items-center justify-between">
                      <span>{profile?.email || "Your account email"}</span>
                      <Mail className="size-4 text-ink-muted" />
                    </div>
                  </div>

                  {/* Delivery notice */}
                  <div className="rounded-2xl p-3.5 bg-emerald-500/10 border border-emerald-500/25 flex items-start gap-2.5 text-xs text-emerald-400 font-medium leading-relaxed">
                    <ShieldCheck className="size-4 shrink-0 mt-0.5 text-emerald-400" />
                    <span>
                      Your digital gift code, PIN, and redemption guide will be delivered directly
                      to your registered inbox once verified.
                    </span>
                  </div>
                </div>
              )}
            </div>
          )}

          <DialogFooter className="gap-2 sm:gap-0 pt-2">
            <Button
              variant="outline"
              className="rounded-xl font-bold h-11 text-xs border-hairline hover:bg-ink-3 cursor-pointer"
              onClick={() => setSelectedReward(null)}
              disabled={isRedeeming}
            >
              Cancel
            </Button>
            <Button
              className={cn(
                "rounded-xl font-bold h-11 text-xs cursor-pointer shadow-md",
                isSelectedCrypto
                  ? "bg-amber-500 text-ink hover:bg-amber-400 shadow-amber-500/10 font-black"
                  : "bg-gold text-ink hover:bg-gold-soft shadow-gold/10 font-black",
              )}
              onClick={handleRedeem}
              disabled={isRedeeming || (isSelectedCrypto && !walletAddress.trim())}
            >
              {isRedeeming ? (
                <span className="flex items-center gap-2">
                  <Loader2 className="size-4 animate-spin" /> Processing...
                </span>
              ) : (
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="size-4" />
                  <span>
                    {isSelectedCrypto ? "Confirm & Withdraw USDT" : "Confirm & Claim Gift Card"}
                  </span>
                </span>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </motion.div>
  );
}

export default RedeemPage;
