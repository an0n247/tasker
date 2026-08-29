import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Gift,
  Coins,
  ShoppingBag,
  CreditCard,
  Ticket,
  ArrowRight,
  Wallet,
  History as HistoryIcon,
  Loader2,
  Sparkles,
  ShieldCheck,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  ChevronRight,
  Filter,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
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
import { motion, AnimatePresence } from "framer-motion";

export const Route = createFileRoute("/_authenticated/redeem")({
  head: () => ({
    title: "Redeem Rewards | Marketplace & Gift Cards | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Exchange your hard-earned Noble Gain points for premium gift cards, vouchers, and exclusive products in our rewards marketplace.",
      },
      { property: "og:title", content: "Redeem Points | Noble Gain Marketplace" },
      {
        property: "og:description",
        content:
          "Turn your points into real-world rewards. Browse our catalog of gift cards and premium vouchers.",
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

function RedeemPage() {
  const [activeCategory, setActiveCategory] = useState("All");
  const [selectedReward, setSelectedReward] = useState<any>(null);
  const [isRedeeming, setIsRedeeming] = useState(false);
  const queryClient = useQueryClient();

  const { data: rewards, isLoading } = useQuery({
    queryKey: ["rewards"],
    queryFn: async () => {
      const { data } = await supabase
        .from("rewards")
        .select("*")
        .eq("is_active", true)
        .order("cost_points", { ascending: true });
      return data || [];
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

  const categories = [
    { name: "All", icon: Sparkles },
    { name: "Gift Cards", icon: CreditCard },
    { name: "Vouchers", icon: Ticket },
    { name: "Products", icon: ShoppingBag },
  ];

  const filteredRewards =
    activeCategory === "All"
      ? rewards
      : rewards?.filter((r: any) => r.category?.toLowerCase() === activeCategory.toLowerCase());

  const userBalance = profile?.points_balance || 0;

  const handleRedeem = async () => {
    if (!selectedReward || !profile) return;

    setIsRedeeming(true);
    try {
      const { data, error } = await supabase.rpc("redeem_reward", {
        _reward_id: selectedReward.id,
      });

      if (error) throw error;

      const result = data as { success: boolean; message: string } | null;

      if (!result?.success) {
        toast.error(result?.message || "Failed to redeem reward. Please try again.");
        return;
      }

      confetti({
        particleCount: 90,
        spread: 70,
        origin: { y: 0.6 },
      });

      toast.success(
        "Redemption request submitted! Details will be sent to your registered email address.",
      );
      setSelectedReward(null);

      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["redemptions"] });
      queryClient.invalidateQueries({ queryKey: ["rewards"] });
    } catch (error: any) {
      console.error("Redemption error:", error);
      toast.error("Failed to redeem reward. Please try again.");
    } finally {
      setIsRedeeming(false);
    }
  };

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
            <span className="text-ink-fg/70 font-medium">Instant Redemption</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Redeem <span className="text-gold">Rewards</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Exchange your earned points for verified digital gift cards, cash vouchers, and
            exclusive perks.
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
          <Filter className="size-3.5" /> Filter:
        </span>
        {categories.map((cat) => {
          const isActive = activeCategory === cat.name;
          return (
            <button
              key={cat.name}
              type="button"
              onClick={() => setActiveCategory(cat.name)}
              className={cn(
                "rounded-xl font-bold h-10 px-4 text-xs shrink-0 transition-all flex items-center gap-2 border cursor-pointer",
                isActive
                  ? "bg-gold text-ink font-black border-gold shadow-md shadow-gold/10"
                  : "bg-ink-2/60 border-hairline text-ink-muted hover:text-ink-fg hover:bg-ink-3",
              )}
            >
              <cat.icon className={cn("size-4", isActive ? "text-ink" : "text-gold")} />
              <span>{cat.name}</span>
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
                          <Gift className="size-14 text-gold/30" />
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
                        <span className="bg-ink/90 backdrop-blur-md text-ink-fg border border-hairline font-bold uppercase text-[10px] tracking-wider rounded-lg px-2.5 py-1">
                          {reward.category || "General"}
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
                          "Digital voucher delivered instantly upon verification."}
                      </p>
                    </div>
                  </div>

                  {/* Action Button Area */}
                  <div className="p-6 pt-0">
                    <Button
                      className={cn(
                        "w-full rounded-xl font-bold h-11 text-xs transition-all shadow-md cursor-pointer",
                        canAfford
                          ? "bg-gold text-ink hover:bg-gold-soft hover:-translate-y-0.5 shadow-gold/10 font-black"
                          : "bg-ink-3 text-ink-muted border border-hairline hover:bg-ink-3/80 shadow-none cursor-not-allowed",
                      )}
                      disabled={!canAfford}
                      onClick={() => setSelectedReward(reward)}
                    >
                      {canAfford ? (
                        <span className="flex items-center gap-1.5">
                          <span>Redeem Reward</span>
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
                  <ShoppingBag className="size-8 text-gold" />
                </div>
                <div className="space-y-1.5 max-w-sm mx-auto">
                  <h3 className="font-black text-lg text-ink-fg">No rewards found</h3>
                  <p className="text-xs text-ink-muted font-medium">
                    No items are currently listed in this category. Check back soon as new stock is
                    added daily.
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

      {/* Confirmation Modal */}
      <Dialog open={!!selectedReward} onOpenChange={(open) => !open && setSelectedReward(null)}>
        <DialogContent className="rounded-3xl max-w-md bg-ink-2 border border-hairline text-ink-fg p-6 sm:p-7 shadow-2xl backdrop-blur-2xl">
          <DialogHeader className="space-y-2">
            <div className="size-12 rounded-2xl bg-gold/15 border border-gold/30 text-gold flex items-center justify-center mb-1">
              <Gift className="size-6" />
            </div>
            <DialogTitle className="text-xl font-black tracking-tight text-ink-fg">
              Confirm Redemption
            </DialogTitle>
            <DialogDescription className="text-xs text-ink-muted leading-relaxed font-medium">
              You are about to redeem your points for this reward. Please verify the details below.
            </DialogDescription>
          </DialogHeader>

          {selectedReward && (
            <div className="py-4 space-y-4">
              {/* Item Card Preview */}
              <div className="rounded-2xl p-4 bg-ink border border-hairline space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-ink-fg">{selectedReward.title}</span>
                  <span className="text-xs font-black font-mono text-gold bg-gold/10 px-2.5 py-1 rounded-lg border border-gold/25">
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

              {/* Delivery notice */}
              <div className="rounded-2xl p-3.5 bg-emerald-500/10 border border-emerald-500/25 flex items-start gap-2.5 text-xs text-emerald-400 font-medium">
                <ShieldCheck className="size-4 shrink-0 mt-0.5 text-emerald-400" />
                <span>
                  Your digital redemption code will be emailed immediately after security
                  confirmation.
                </span>
              </div>
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
              className="rounded-xl font-bold h-11 text-xs bg-gold text-ink hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10"
              onClick={handleRedeem}
              disabled={isRedeeming}
            >
              {isRedeeming ? (
                <span className="flex items-center gap-2">
                  <Loader2 className="size-4 animate-spin" /> Processing...
                </span>
              ) : (
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="size-4" /> Confirm & Claim Reward
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
