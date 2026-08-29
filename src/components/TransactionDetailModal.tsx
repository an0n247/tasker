import React from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Coins,
  Calendar,
  Tag,
  Hash,
  ArrowUpRight,
  ArrowDownRight,
  Clock,
  CheckCircle2,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export interface Transaction {
  id: string;
  description: string | null;
  amount: number;
  type: string;
  status?: string | null;
  created_at: string;
}

interface TransactionDetailModalProps {
  transaction: Transaction | null;
  isOpen: boolean;
  onClose: () => void;
}

export function TransactionDetailModal({
  transaction,
  isOpen,
  onClose,
}: TransactionDetailModalProps) {
  if (!transaction) return null;

  const isPositive = transaction.amount > 0;
  const isPending = transaction.status === "pending";

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md rounded-3xl border border-hairline bg-ink-2 text-ink-fg shadow-2xl overflow-hidden p-0 gap-0 backdrop-blur-2xl">
        <DialogHeader className="p-6 pb-0 text-left">
          <DialogTitle className="text-xl font-black tracking-tight text-ink-fg flex items-center gap-2">
            Transaction Details
          </DialogTitle>
          <DialogDescription className="text-ink-muted text-xs font-medium pt-1">
            Complete cryptographic audit trail for this ledger entry.
          </DialogDescription>
        </DialogHeader>

        <div className="p-6 space-y-5">
          {/* Hero Amount Card */}
          <div
            className={cn(
              "rounded-2xl p-6 flex flex-col items-center justify-center text-center space-y-1.5 border shadow-sm relative overflow-hidden",
              isPending
                ? "bg-amber-500/10 border-amber-500/25 text-amber-400"
                : isPositive
                  ? "bg-emerald-500/10 border-emerald-500/25 text-emerald-400"
                  : "bg-rose-500/10 border-rose-500/25 text-rose-400",
            )}
          >
            <div
              className={cn(
                "p-3 rounded-2xl mb-1 border",
                isPending
                  ? "bg-amber-500/20 border-amber-500/30 text-amber-400"
                  : isPositive
                    ? "bg-emerald-500/20 border-emerald-500/30 text-emerald-400"
                    : "bg-rose-500/20 border-rose-500/30 text-rose-400",
              )}
            >
              {isPending ? (
                <Clock className="size-6" />
              ) : isPositive ? (
                <ArrowUpRight className="size-6" />
              ) : (
                <ArrowDownRight className="size-6" />
              )}
            </div>
            <span className="text-4xl font-black font-mono tracking-tight">
              {isPending ? "" : isPositive ? "+" : ""}
              {transaction.amount} <span className="text-sm">PTS</span>
            </span>
            <span className="text-[10px] font-black uppercase tracking-[0.2em] opacity-80">
              {isPending
                ? "Pending Verification"
                : isPositive
                  ? "Points Credited"
                  : "Points Redeemed"}
            </span>
            {isPending && (
              <div className="absolute top-3 right-3">
                <span className="text-[9px] border border-amber-500/30 text-amber-400 bg-amber-500/15 uppercase font-bold px-2 py-0.5 rounded-md">
                  Pending
                </span>
              </div>
            )}
          </div>

          {/* Details List */}
          <div className="space-y-2.5 bg-ink rounded-2xl p-4 border border-hairline">
            <div className="flex items-start gap-3 p-2 rounded-xl">
              <div className="bg-gold/15 p-2 rounded-xl text-gold border border-gold/25 shrink-0">
                <Tag className="size-4" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                  Description
                </p>
                <p className="text-xs font-bold text-ink-fg break-words">
                  {transaction.description || "Point Movement"}
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3 p-2 rounded-xl">
              <div className="bg-emerald-500/15 p-2 rounded-xl text-emerald-400 border border-emerald-500/25 shrink-0">
                <Coins className="size-4" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                  Type
                </p>
                <p className="text-xs font-bold text-ink-fg capitalize">
                  {transaction.type.replace("_", " ")}
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3 p-2 rounded-xl">
              <div className="bg-blue-500/15 p-2 rounded-xl text-blue-400 border border-blue-500/25 shrink-0">
                <Calendar className="size-4" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                  Date & Time
                </p>
                <p className="text-xs font-bold text-ink-fg">
                  {new Date(transaction.created_at).toLocaleString(undefined, {
                    dateStyle: "long",
                    timeStyle: "medium",
                  })}
                </p>
              </div>
            </div>

            <div className="flex items-start gap-3 p-2 rounded-xl">
              <div className="bg-purple-500/15 p-2 rounded-xl text-purple-400 border border-purple-500/25 shrink-0">
                <Hash className="size-4" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                  Transaction ID
                </p>
                <p className="text-[10px] font-mono font-bold text-ink-muted truncate">
                  {transaction.id}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="p-4 bg-ink-3/40 border-t border-hairline flex justify-end">
          <Button
            onClick={onClose}
            className="rounded-xl bg-gold text-ink font-bold text-xs h-10 px-5 hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10"
          >
            Close Details
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
