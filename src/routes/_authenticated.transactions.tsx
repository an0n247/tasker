import { createFileRoute } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery } from "@tanstack/react-query";
import {
  History,
  Coins,
  Loader2,
  Gift,
  TrendingUp,
  ArrowRight,
  Clock,
  ArrowUpRight,
  ArrowDownRight,
  Filter,
  Sparkles,
  Wallet,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { TransactionDetailModal, Transaction } from "@/components/TransactionDetailModal";
import { useEffect, useState } from "react";
import { z } from "zod";
import { motion } from "framer-motion";

const transactionSearchSchema = z.object({
  transactionId: z.string().optional(),
});

export const Route = createFileRoute("/_authenticated/transactions")({
  validateSearch: (search) => transactionSearchSchema.parse(search),
  head: () => ({
    title: "Transaction History & Ledger | Noble Gain",
    meta: [
      {
        name: "description",
        content: "Complete cryptographic audit trail of all points earned and spent on Noble Gain.",
      },
      { property: "og:title", content: "Transaction Ledger | Noble Gain" },
      {
        property: "og:description",
        content: "Detailed view of your point earnings and reward redemptions.",
      },
    ],
  }),
  component: TransactionsPage,
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

function TransactionsPage() {
  const { transactionId } = Route.useSearch();
  const [selectedTx, setSelectedTx] = useState<Transaction | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [filterType, setFilterType] = useState<"all" | "credits" | "debits" | "pending">("all");

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

  const { data: transactions, isLoading: isTransactionsLoading } = useQuery({
    queryKey: ["transactions"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return [];
      const { data } = await supabase
        .from("points_transactions")
        .select("*")
        .eq("user_id", user.id)
        .order("created_at", { ascending: false });
      return data || [];
    },
  });

  useEffect(() => {
    if (transactionId && transactions) {
      const tx = transactions.find((t: any) => t.id === transactionId);
      if (tx) {
        setSelectedTx(tx);
        setIsModalOpen(true);
      } else {
        const fetchIndividual = async () => {
          const { data, error } = await supabase
            .from("points_transactions")
            .select("*")
            .eq("id", transactionId)
            .single();

          if (data && !error) {
            setSelectedTx(data);
            setIsModalOpen(true);
          }
        };
        fetchIndividual();
      }
    }
  }, [transactionId, transactions]);

  const handleTxClick = (tx: Transaction) => {
    setSelectedTx(tx);
    setIsModalOpen(true);
  };

  // Filter calculations
  const filteredList =
    transactions?.filter((tx: any) => {
      if (filterType === "credits") return tx.amount > 0 && tx.status !== "pending";
      if (filterType === "debits") return tx.amount < 0 && tx.status !== "pending";
      if (filterType === "pending") return tx.status === "pending";
      return true;
    }) || [];

  const totalEarned =
    transactions
      ?.filter((t: any) => t.amount > 0 && t.status !== "pending")
      .reduce((acc: number, cur: any) => acc + cur.amount, 0) || 0;
  const totalRedeemed = Math.abs(
    transactions
      ?.filter((t: any) => t.amount < 0 && t.status !== "pending")
      .reduce((acc: number, cur: any) => acc + cur.amount, 0) || 0,
  );

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-5xl mx-auto pb-12"
    >
      {/* Ambient background light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <History className="size-3.5" />
            <span>Activity Ledger</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Real-Time Audit Trail</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Transaction <span className="text-gold">History</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Detailed ledger of all points earned from tasks and redeemed for rewards.
          </p>
        </div>
      </motion.header>

      {/* Summary Metrics Bar */}
      <motion.div variants={fadeInUp} className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Current Vault
            </span>
            <div className="size-8 rounded-xl bg-gold/15 text-gold flex items-center justify-center border border-gold/25">
              <Wallet className="size-4" />
            </div>
          </div>
          <p className="text-2xl font-black font-mono text-gold">
            {(profile?.points_balance || 0).toLocaleString()}{" "}
            <span className="text-xs font-bold">PTS</span>
          </p>
        </div>

        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Total Earned
            </span>
            <div className="size-8 rounded-xl bg-emerald-500/15 text-emerald-400 flex items-center justify-center border border-emerald-500/25">
              <ArrowUpRight className="size-4" />
            </div>
          </div>
          <p className="text-2xl font-black font-mono text-emerald-400">
            +{totalEarned.toLocaleString()} <span className="text-xs font-bold">PTS</span>
          </p>
        </div>

        <div className="rounded-3xl p-5 bg-ink-2/70 border border-hairline shadow-md backdrop-blur-xl">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-ink-muted">
              Total Redeemed
            </span>
            <div className="size-8 rounded-xl bg-rose-500/15 text-rose-400 flex items-center justify-center border border-rose-500/25">
              <Gift className="size-4" />
            </div>
          </div>
          <p className="text-2xl font-black font-mono text-rose-400">
            -{totalRedeemed.toLocaleString()} <span className="text-xs font-bold">PTS</span>
          </p>
        </div>
      </motion.div>

      {/* Filter Tabs & Ledger Card */}
      <motion.div variants={fadeInUp} className="space-y-4">
        <div className="flex p-1.5 bg-ink-2/80 rounded-2xl border border-hairline shadow-sm w-fit max-w-full overflow-x-auto scrollbar-none">
          <button
            type="button"
            onClick={() => setFilterType("all")}
            className={cn(
              "px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer",
              filterType === "all"
                ? "bg-gold text-ink font-black shadow-md"
                : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
            )}
          >
            All Activity ({transactions?.length || 0})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("credits")}
            className={cn(
              "px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer",
              filterType === "credits"
                ? "bg-gold text-ink font-black shadow-md"
                : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
            )}
          >
            Earnings Only
          </button>
          <button
            type="button"
            onClick={() => setFilterType("debits")}
            className={cn(
              "px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer",
              filterType === "debits"
                ? "bg-gold text-ink font-black shadow-md"
                : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
            )}
          >
            Redemptions Only
          </button>
          <button
            type="button"
            onClick={() => setFilterType("pending")}
            className={cn(
              "px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer",
              filterType === "pending"
                ? "bg-gold text-ink font-black shadow-md"
                : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
            )}
          >
            Pending
          </button>
        </div>

        <div className="rounded-3xl border border-hairline bg-ink-2/70 shadow-lg overflow-hidden backdrop-blur-xl">
          {isTransactionsLoading ? (
            <div className="flex justify-center p-16">
              <Loader2 className="size-8 animate-spin text-gold" />
            </div>
          ) : filteredList.length ? (
            <div className="divide-y divide-hairline">
              {filteredList.map((tx: any) => {
                const isPending = tx.status === "pending";
                const isPositive = tx.amount > 0;

                return (
                  <div
                    key={tx.id}
                    className="flex items-center justify-between p-5 hover:bg-ink-3/40 transition-colors cursor-pointer group"
                    onClick={() => handleTxClick(tx)}
                  >
                    <div className="flex items-center gap-4">
                      <div
                        className={cn(
                          "size-10 rounded-2xl flex items-center justify-center border shrink-0 transition-transform group-hover:scale-105",
                          isPending
                            ? "bg-amber-500/15 text-amber-400 border-amber-500/30"
                            : isPositive
                              ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/30"
                              : "bg-rose-500/15 text-rose-400 border-rose-500/30",
                        )}
                      >
                        {isPending ? (
                          <Clock className="size-4" />
                        ) : isPositive ? (
                          <ArrowUpRight className="size-4" />
                        ) : (
                          <Gift className="size-4" />
                        )}
                      </div>

                      <div className="space-y-1">
                        <p className="font-bold text-sm text-ink-fg group-hover:text-gold transition-colors flex items-center gap-2">
                          <span>{tx.description || "Point Movement"}</span>
                          {isPending && (
                            <span className="text-[9px] font-black uppercase text-amber-400 bg-amber-500/15 border border-amber-500/30 px-1.5 py-0.5 rounded-md">
                              Pending
                            </span>
                          )}
                        </p>
                        <p className="text-[10px] text-ink-muted font-bold uppercase tracking-wider">
                          {new Date(tx.created_at).toLocaleString()}
                        </p>
                      </div>
                    </div>

                    <div
                      className={cn(
                        "font-black font-mono text-sm px-3.5 py-1.5 rounded-xl border",
                        isPending
                          ? "bg-amber-500/15 text-amber-400 border-amber-500/30"
                          : isPositive
                            ? "bg-emerald-500/15 text-emerald-400 border-emerald-500/30"
                            : "bg-rose-500/15 text-rose-400 border-rose-500/30",
                      )}
                    >
                      {isPending ? "" : isPositive ? "+" : ""}
                      {tx.amount} PTS
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="p-16 text-center space-y-3">
              <div className="size-12 rounded-2xl bg-ink-3 text-gold/40 flex items-center justify-center mx-auto border border-hairline">
                <History className="size-6" />
              </div>
              <p className="text-sm font-black text-ink-fg">No transactions recorded</p>
              <p className="text-xs text-ink-muted font-medium max-w-sm mx-auto">
                {filterType !== "all"
                  ? "No transactions match the selected filter category."
                  : "Complete tasks or redeem rewards to build your points transaction history."}
              </p>
            </div>
          )}
        </div>
      </motion.div>

      <TransactionDetailModal
        transaction={selectedTx}
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
      />
    </motion.div>
  );
}

export default TransactionsPage;
