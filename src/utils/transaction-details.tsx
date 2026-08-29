import { toast } from "sonner";
import React from "react";

export interface TransactionDetails {
  id: string;
  description: string | null;
  amount: number;
  type: string;
  created_at: string;
}

export const showTransactionDetails = (tx: TransactionDetails) => {
  console.log("Showing transaction details toast for:", tx.id);
  toast.info(
    <div className="space-y-2">
      <p className="font-bold text-sm text-foreground leading-none">Transaction Details</p>
      <div className="text-xs space-y-1 font-medium">
        <p>
          <span className="text-muted-foreground uppercase text-[10px] font-black mr-2">
            Description:
          </span>
          {tx.description || "No description"}
        </p>
        <p>
          <span className="text-muted-foreground uppercase text-[10px] font-black mr-2">
            Amount:
          </span>
          <span className={tx.amount > 0 ? "text-green-600" : "text-destructive"}>
            {tx.amount > 0 ? "+" : ""}
            {tx.amount} PTS
          </span>
        </p>
        <p>
          <span className="text-muted-foreground uppercase text-[10px] font-black mr-2">Type:</span>
          <span className="capitalize">{tx.type.replace("_", " ")}</span>
        </p>
        <p>
          <span className="text-muted-foreground uppercase text-[10px] font-black mr-2">Date:</span>
          {new Date(tx.created_at).toLocaleString()}
        </p>
        <p className="pt-1 opacity-50">
          <span className="text-[9px] uppercase font-black mr-2">ID:</span>
          {tx.id}
        </p>
      </div>
    </div>,
    {
      duration: 6000,
      className: "border-primary/20 bg-card shadow-lg",
    },
  );
};
