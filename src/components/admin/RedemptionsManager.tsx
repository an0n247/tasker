import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { toast } from "sonner";
import { Check, X, Loader2, Search, Filter, ChevronLeft, ChevronRight } from "lucide-react";
import { format } from "date-fns";
import { useState } from "react";
import { cn } from "@/lib/utils";

export function RedemptionsManager() {
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [rejectionReason, setRejectionReason] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["admin-redemptions", searchTerm, statusFilter, currentPage],
    queryFn: async () => {
      let query = supabase.from("redemptions").select(
        `
          *,
          profiles:user_id(full_name, email, username),
          rewards:reward_id(title, cost_points)
        `,
        { count: "exact" },
      );

      if (statusFilter !== "all") {
        query = query.eq("status", statusFilter);
      }

      if (searchTerm) {
        // Search across related tables can be tricky in Supabase via one query
        // We'll keep basic filtering for now or use a more advanced approach if needed
      }

      const from = (currentPage - 1) * itemsPerPage;
      const to = from + itemsPerPage - 1;

      const { data, count, error } = await query
        .order("created_at", { ascending: false })
        .range(from, to);

      if (error) throw error;
      return { redemptions: data, totalCount: count || 0 };
    },
  });

  const redemptions = data?.redemptions || [];
  const totalCount = data?.totalCount || 0;
  const totalPages = Math.ceil(totalCount / itemsPerPage);

  const updateStatusMutation = useMutation({
    mutationFn: async ({
      id,
      status,
      userId,
      rewardTitle,
      reason,
    }: {
      id: string;
      status: string;
      userId: string;
      rewardTitle: string;
      reason?: string;
    }) => {
      const { data, error } = await supabase.rpc("process_redemption_status_change", {
        _redemption_id: id,
        _new_status: status,
        _rejection_reason: reason || "",
      });

      if (error) throw error;

      const result = data as any;
      if (!result.success) {
        throw new Error(result.message);
      }

      // Notify the user via the privileged notification RPC
      await supabase.rpc("send_user_notification", {
        _user_id: userId,
        _title: status === "approved" ? "Redemption Approved!" : "Redemption Rejected",
        _message:
          status === "approved"
            ? `Your request for "${rewardTitle}" has been approved.${result.re_deducted ? " The points were re-deducted from your balance." : ""}`
            : `Your request for "${rewardTitle}" was rejected.${reason ? ` Reason: ${reason}.` : ""}${result.refunded ? " The points have been returned to your balance." : ""}`,
        _type: "redemption",
      });

      return result;
    },
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["admin-redemptions"] });
      queryClient.invalidateQueries({ queryKey: ["adminStats"] });
      setRejectionReason("");

      let message = "Redemption status updated";
      if (result.refunded) message += " and points refunded";
      if (result.re_deducted) message += " and points re-deducted";

      toast.success(message);
    },
    onError: (error) => {
      toast.error("Failed to update status: " + error.message);
    },
  });

  const filteredRedemptions = redemptions;

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
        <div className="relative w-full md:w-96">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search users or rewards..."
            className="pl-10 rounded-xl"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2 w-full md:w-auto">
          <Filter className="h-4 w-4 text-muted-foreground" />
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-full md:w-[180px] rounded-xl">
              <SelectValue placeholder="Filter by status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="pending">Pending</SelectItem>
              <SelectItem value="approved">Approved</SelectItem>
              <SelectItem value="rejected">Rejected</SelectItem>
              <SelectItem value="review_required">Fraud Alert</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div className="rounded-2xl border border-border/50 bg-card overflow-hidden overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50">
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[150px]">
                User
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[150px]">
                Reward
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Cost
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Date
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Status
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredRedemptions?.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="text-center py-12 text-muted-foreground font-medium"
                >
                  No redemptions found matching your criteria.
                </TableCell>
              </TableRow>
            ) : (
              filteredRedemptions?.map((r: any) => (
                <TableRow
                  key={r.id}
                  className="border-border/40 hover:bg-accent/5 transition-colors"
                >
                  <TableCell className="px-6 py-4">
                    <div className="font-bold">{r.profiles?.full_name || r.profiles?.username}</div>
                    <div className="text-xs text-muted-foreground">{r.profiles?.email}</div>
                  </TableCell>
                  <TableCell className="px-6 py-4 font-medium">
                    <div>{r.rewards?.title}</div>
                    {r.rejection_reason && (
                      <div className="text-[10px] text-destructive font-bold uppercase tracking-tighter mt-1">
                        Reason: {r.rejection_reason}
                      </div>
                    )}
                    {r.is_flagged && (
                      <div className="flex flex-col gap-1 mt-2">
                        <Badge
                          variant="destructive"
                          className="w-fit text-[9px] font-black tracking-tighter rounded-md px-1 py-0 h-4"
                        >
                          FRAUD ALERT
                        </Badge>
                        <div className="text-[9px] text-muted-foreground font-medium leading-tight max-w-[200px]">
                          Flags: {(r.fraud_details as any)?.flags?.join(", ")} (Score:{" "}
                          {r.fraud_score?.toFixed(1)})
                        </div>
                      </div>
                    )}
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <Badge
                      variant="outline"
                      className="font-bold text-primary border-primary/20 bg-primary/5"
                    >
                      {r.rewards?.cost_points} pts
                    </Badge>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-xs text-muted-foreground font-medium text-center">
                    {format(new Date(r.created_at), "MMM d, yyyy")}
                  </TableCell>
                  <TableCell className="px-6 py-4 text-center">
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <button className="focus:outline-none">
                          <Badge
                            className={cn(
                              "font-black uppercase text-[10px] tracking-wider px-2 py-0.5 cursor-pointer",
                              r.status === "pending" &&
                                "bg-orange-500/10 text-orange-600 hover:bg-orange-500/20",
                              r.status === "approved" &&
                                "bg-green-500/10 text-green-600 hover:bg-green-500/20",
                              r.status === "rejected" &&
                                "bg-destructive/10 text-destructive hover:bg-destructive/20",
                              r.status === "review_required" &&
                                "bg-red-500/10 text-red-600 hover:bg-red-500/20 animate-pulse",
                            )}
                          >
                            {r.status}
                          </Badge>
                        </button>
                      </AlertDialogTrigger>
                      <AlertDialogContent className="rounded-2xl border-border/50">
                        <AlertDialogHeader>
                          <AlertDialogTitle className="font-black text-xl">
                            Update Status
                          </AlertDialogTitle>
                          <div className="font-medium text-sm space-y-4 text-muted-foreground">
                            <div>
                              Update the status for{" "}
                              <span className="text-primary font-bold">"{r.rewards?.title}"</span>{" "}
                              by{" "}
                              <span className="font-bold">
                                {r.profiles?.full_name || r.profiles?.username}
                              </span>
                              .
                            </div>

                            <div className="space-y-2">
                              <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                                Rejection Reason (Required for rejection)
                              </label>
                              <Input
                                placeholder="e.g. Invalid account details, duplicate request..."
                                value={rejectionReason}
                                onChange={(e) => setRejectionReason(e.target.value)}
                                className="rounded-xl"
                              />
                            </div>

                            <div className="flex flex-col gap-2 pt-2">
                              <Button
                                className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest bg-green-600 hover:bg-green-700"
                                onClick={() => {
                                  updateStatusMutation.mutate({
                                    id: r.id,
                                    status: "approved",
                                    userId: r.user_id,
                                    rewardTitle: r.rewards?.title,
                                  });
                                }}
                                disabled={r.status === "approved" || updateStatusMutation.isPending}
                              >
                                <Check className="mr-2 h-4 w-4" /> Approve Redemption
                              </Button>
                              <Button
                                variant="destructive"
                                className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest"
                                onClick={() => {
                                  if (!rejectionReason.trim()) {
                                    toast.error("Please provide a rejection reason");
                                    return;
                                  }
                                  updateStatusMutation.mutate({
                                    id: r.id,
                                    status: "rejected",
                                    userId: r.user_id,
                                    rewardTitle: r.rewards?.title,
                                    reason: rejectionReason,
                                  });
                                }}
                                disabled={r.status === "rejected" || updateStatusMutation.isPending}
                              >
                                <X className="mr-2 h-4 w-4" /> Reject Redemption
                              </Button>
                              <Button
                                variant="outline"
                                className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest"
                                onClick={() => {
                                  updateStatusMutation.mutate({
                                    id: r.id,
                                    status: "pending",
                                    userId: r.user_id,
                                    rewardTitle: r.rewards?.title,
                                  });
                                }}
                                disabled={r.status === "pending" || updateStatusMutation.isPending}
                              >
                                <Loader2 className="mr-2 h-4 w-4" /> Set to Pending
                              </Button>
                            </div>
                          </div>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel className="rounded-xl font-bold uppercase text-[10px] tracking-widest w-full">
                            Close
                          </AlertDialogCancel>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between px-2 py-4 border-t border-border/40">
          <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest">
            Showing {(currentPage - 1) * itemsPerPage + 1} to{" "}
            {Math.min(currentPage * itemsPerPage, totalCount)} of {totalCount} entries
          </p>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              className="rounded-xl h-9 px-3 font-bold border-border/50"
              disabled={currentPage === 1}
              onClick={() => setCurrentPage((prev) => prev - 1)}
            >
              <ChevronLeft className="h-4 w-4 mr-1" />
              Previous
            </Button>
            <div className="flex items-center gap-1">
              {Array.from({ length: Math.min(totalPages, 5) }).map((_, i) => (
                <Button
                  key={i}
                  variant={currentPage === i + 1 ? "default" : "outline"}
                  size="sm"
                  className={cn(
                    "h-9 w-9 rounded-xl font-bold p-0 border-border/50",
                    currentPage === i + 1 && "shadow-md shadow-primary/20",
                  )}
                  onClick={() => setCurrentPage(i + 1)}
                >
                  {i + 1}
                </Button>
              ))}
              {totalPages > 5 && <span className="text-muted-foreground">...</span>}
            </div>
            <Button
              variant="outline"
              size="sm"
              className="rounded-xl h-9 px-3 font-bold border-border/50"
              disabled={currentPage === totalPages}
              onClick={() => setCurrentPage((prev) => prev + 1)}
            >
              Next
              <ChevronRight className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
