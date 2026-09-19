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
import {
  Check,
  X,
  Loader2,
  Search,
  Filter,
  ChevronLeft,
  ChevronRight,
  Copy,
  Coins,
  Mail,
  Gift,
  CheckCircle2,
  XCircle,
  Eye,
  AlertTriangle,
} from "lucide-react";
import { format } from "date-fns";
import { useState } from "react";
import { cn } from "@/lib/utils";

export function RedemptionsManager() {
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [rejectionReason, setRejectionReason] = useState("");
  const [selectedRedemptionForDecline, setSelectedRedemptionForDecline] = useState<any>(null);
  const [selectedRedemptionForApprove, setSelectedRedemptionForApprove] = useState<any>(null);
  const [selectedRedemptionForView, setSelectedRedemptionForView] = useState<any>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;
  const queryClient = useQueryClient();

  const { data, isLoading, isError, error: queryError } = useQuery({
    queryKey: ["admin-redemptions", statusFilter, currentPage],
    queryFn: async () => {
      let query = supabase.from("redemptions").select(
        `
          *,
          rewards:reward_id(title, cost_points, category)
        `,
        { count: "exact" },
      );

      if (statusFilter !== "all") {
        query = query.eq("status", statusFilter);
      }

      const from = (currentPage - 1) * itemsPerPage;
      const to = from + itemsPerPage - 1;

      const { data: redemptionsData, count, error } = await query
        .order("created_at", { ascending: false })
        .range(from, to);

      if (error) {
        console.error("Error fetching redemptions:", error);
        throw error;
      }

      const rawList = redemptionsData || [];
      const userIds = Array.from(new Set(rawList.map((r: any) => r.user_id).filter(Boolean)));

      let profileMap = new Map();
      if (userIds.length > 0) {
        const { data: profilesData, error: profilesError } = await supabase
          .from("profiles")
          .select("id, full_name, email, username, phone_number, twitter_handle, telegram_handle")
          .in("id", userIds);

        if (!profilesError && profilesData) {
          profileMap = new Map(profilesData.map((p) => [p.id, p]));
        } else if (profilesError) {
          console.warn("Could not fetch profiles for redemptions:", profilesError);
        }
      }

      const enriched = rawList.map((r: any) => ({
        ...r,
        profiles: profileMap.get(r.user_id) || null,
      }));

      return { redemptions: enriched, totalCount: count || 0 };
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
      try {
        await supabase.rpc("send_user_notification", {
          _user_id: userId,
          _title: status === "approved" ? "Redemption Approved!" : "Redemption Rejected",
          _message:
            status === "approved"
              ? `Your request for "${rewardTitle}" has been approved.${result.re_deducted ? " The points were re-deducted from your balance." : ""}`
              : `Your request for "${rewardTitle}" was rejected.${reason ? ` Reason: ${reason}.` : ""}${result.refunded ? " The points have been returned to your balance." : ""}`,
          _type: "redemption",
        });
      } catch (notifyErr) {
        console.warn("Could not send user notification:", notifyErr);
      }

      return result;
    },
    onSuccess: (result) => {
      queryClient.invalidateQueries({ queryKey: ["admin-redemptions"] });
      queryClient.invalidateQueries({ queryKey: ["adminStats"] });
      setRejectionReason("");
      setSelectedRedemptionForDecline(null);
      setSelectedRedemptionForApprove(null);
      setSelectedRedemptionForView(null);

      let message = "Redemption status updated";
      if (result.refunded) message += " and points refunded to user";
      if (result.re_deducted) message += " and points re-deducted";

      toast.success(message);
    },
    onError: (error) => {
      toast.error("Failed to update status: " + error.message);
    },
  });

  const filteredRedemptions = redemptions.filter((r: any) => {
    if (!searchTerm.trim()) return true;
    const term = searchTerm.toLowerCase();
    const fullName = (r.profiles?.full_name || "").toLowerCase();
    const username = (r.profiles?.username || "").toLowerCase();
    const email = (r.profiles?.email || "").toLowerCase();
    const phone = (r.profiles?.phone_number || "").toLowerCase();
    const twitter = (r.profiles?.twitter_handle || "").toLowerCase();
    const telegram = (r.profiles?.telegram_handle || "").toLowerCase();
    const rewardTitle = (r.rewards?.title || "").toLowerCase();
    const wallet = (r.wallet_address || "").toLowerCase();
    const deliveryEmail = (r.delivery_email || "").toLowerCase();

    return (
      fullName.includes(term) ||
      username.includes(term) ||
      email.includes(term) ||
      phone.includes(term) ||
      twitter.includes(term) ||
      telegram.includes(term) ||
      rewardTitle.includes(term) ||
      wallet.includes(term) ||
      deliveryEmail.includes(term)
    );
  });

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center p-12 gap-3">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">
          Loading redeemed rewards...
        </p>
      </div>
    );
  }

  if (isError) {
    return (
      <div className="p-8 border border-destructive/30 rounded-2xl bg-destructive/5 text-center space-y-3">
        <AlertTriangle className="size-8 text-destructive mx-auto" />
        <h3 className="font-bold text-destructive">Failed to load redemptions</h3>
        <p className="text-xs text-muted-foreground max-w-md mx-auto">
          {(queryError as any)?.message || "An unexpected error occurred while fetching redemptions."}
        </p>
        <Button
          variant="outline"
          size="sm"
          onClick={() => queryClient.invalidateQueries({ queryKey: ["admin-redemptions"] })}
        >
          Try Again
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Top Search & Filter Bar */}
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
        <div className="relative w-full md:w-96">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search users, rewards, wallet or email..."
            className="pl-10 rounded-xl"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="flex items-center gap-2 w-full md:w-auto">
          <Filter className="h-4 w-4 text-muted-foreground" />
          <Select value={statusFilter} onValueChange={(val) => { setStatusFilter(val); setCurrentPage(1); }}>
            <SelectTrigger className="w-full md:w-[190px] rounded-xl">
              <SelectValue placeholder="Filter by status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status ({totalCount})</SelectItem>
              <SelectItem value="pending">Pending</SelectItem>
              <SelectItem value="approved">Approved</SelectItem>
              <SelectItem value="rejected">Rejected</SelectItem>
              <SelectItem value="review_required">Fraud Alert</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Redemptions Table */}
      <div className="rounded-2xl border border-border/50 bg-card overflow-hidden overflow-x-auto shadow-sm">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50 bg-muted/20">
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[170px]">
                User
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[280px]">
                Reward & Payout Destination
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Points Cost
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Date
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Status
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-right min-w-[180px]">
                Actions
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredRedemptions.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="text-center py-16 text-muted-foreground font-medium"
                >
                  <div className="flex flex-col items-center justify-center gap-2">
                    <Gift className="size-8 text-muted-foreground/40 mb-1" />
                    <p className="font-bold text-foreground">No redeemed rewards found</p>
                    <p className="text-xs text-muted-foreground">
                      {searchTerm
                        ? `No results matching "${searchTerm}". Try clearing your search.`
                        : statusFilter !== "all"
                        ? `No rewards with status "${statusFilter}".`
                        : "When users redeem rewards, they will appear here for confirmation."}
                    </p>
                    {(searchTerm || statusFilter !== "all") && (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="mt-2 text-xs font-bold text-primary"
                        onClick={() => {
                          setSearchTerm("");
                          setStatusFilter("all");
                        }}
                      >
                        Reset filters
                      </Button>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            ) : (
              filteredRedemptions.map((r: any) => {
                const isPending = r.status === "pending" || r.status === "review_required";
                const isApproved = r.status === "approved";
                const isRejected = r.status === "rejected";

                return (
                  <TableRow
                    key={r.id}
                    className="border-border/40 hover:bg-accent/5 transition-colors"
                  >
                    {/* User Profile Info */}
                    <TableCell className="px-6 py-4">
                      <div className="font-bold text-foreground">
                        {r.profiles?.full_name || r.profiles?.username || "Anonymous User"}
                      </div>
                      <div className="text-xs text-muted-foreground">
                        {r.profiles?.email || "No email"}
                      </div>
                      {r.profiles?.phone_number && (
                        <div className="text-[11px] text-emerald-600 dark:text-emerald-400 font-semibold mt-0.5">
                          {r.profiles.phone_number}
                        </div>
                      )}
                      {(r.profiles?.twitter_handle || r.profiles?.telegram_handle) && (
                        <div className="flex flex-wrap items-center gap-1 mt-1">
                          {r.profiles.twitter_handle && (
                            <span className="inline-flex items-center gap-0.5 text-[9px] font-bold text-sky-500 bg-sky-500/10 px-1 py-0.2 rounded">
                              𝕏 @{r.profiles.twitter_handle.replace(/^@/, "")}
                            </span>
                          )}
                          {r.profiles.telegram_handle && (
                            <span className="inline-flex items-center gap-0.5 text-[9px] font-bold text-blue-500 bg-blue-500/10 px-1 py-0.2 rounded">
                              ✈ @{r.profiles.telegram_handle.replace(/^@/, "")}
                            </span>
                          )}
                        </div>
                      )}
                    </TableCell>

                    {/* Reward & Payout Destination */}
                    <TableCell className="px-6 py-4 font-medium">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-foreground text-sm">
                          {r.rewards?.title || "Reward"}
                        </span>
                        {r.rewards?.category && (
                          <Badge
                            variant="secondary"
                            className="text-[9px] font-bold uppercase tracking-wider px-1.5 py-0"
                          >
                            {r.rewards.category}
                          </Badge>
                        )}
                      </div>

                      {/* Payout Destination Info */}
                      {r.wallet_address ? (
                        <div className="mt-2 p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/25 max-w-[280px]">
                          <div className="flex items-center justify-between gap-1 text-[10px] font-black text-amber-500 uppercase tracking-wider">
                            <span className="flex items-center gap-1">
                              <Coins className="size-3" /> USDT (TRC20) Wallet
                            </span>
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                navigator.clipboard.writeText(r.wallet_address);
                                toast.success("USDT TRC20 wallet address copied!");
                              }}
                              className="hover:text-amber-400 p-0.5 text-amber-500 cursor-pointer transition-colors"
                              title="Copy wallet address"
                            >
                              <Copy className="size-3" />
                            </button>
                          </div>
                          <div className="font-mono text-[11px] break-all select-all text-foreground font-semibold mt-1">
                            {r.wallet_address}
                          </div>
                        </div>
                      ) : (
                        <div className="mt-2 p-2.5 rounded-xl bg-primary/10 border border-primary/25 max-w-[280px]">
                          <div className="flex items-center justify-between gap-1 text-[10px] font-black text-primary uppercase tracking-wider">
                            <span className="flex items-center gap-1">
                              <Mail className="size-3" /> Delivery Email
                            </span>
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                const emailToCopy = r.delivery_email || r.profiles?.email || "";
                                navigator.clipboard.writeText(emailToCopy);
                                toast.success("Delivery email address copied!");
                              }}
                              className="hover:text-primary/80 p-0.5 text-primary cursor-pointer transition-colors"
                              title="Copy delivery email"
                            >
                              <Copy className="size-3" />
                            </button>
                          </div>
                          <div className="font-mono text-[11px] break-all select-all text-foreground font-semibold mt-1">
                            {r.delivery_email || r.profiles?.email || "User registered email"}
                          </div>
                        </div>
                      )}

                      {r.rejection_reason && (
                        <div className="text-[10px] text-destructive font-bold uppercase tracking-tight mt-1.5">
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
                          <div className="text-[9px] text-muted-foreground font-medium leading-tight max-w-[220px]">
                            Flags: {(r.fraud_details as any)?.flags?.join(", ")} (Score:{" "}
                            {r.fraud_score?.toFixed(1)})
                          </div>
                        </div>
                      )}
                    </TableCell>

                    {/* Points Cost */}
                    <TableCell className="px-6 py-4">
                      <Badge
                        variant="outline"
                        className="font-black text-primary border-primary/20 bg-primary/5 text-xs px-2 py-0.5"
                      >
                        {r.rewards?.cost_points ? `${r.rewards.cost_points.toLocaleString()} pts` : "0 pts"}
                      </Badge>
                    </TableCell>

                    {/* Date */}
                    <TableCell className="px-6 py-4 text-xs text-muted-foreground font-medium text-center whitespace-nowrap">
                      {format(new Date(r.created_at), "MMM d, yyyy")}
                      <div className="text-[10px] text-muted-foreground/60">
                        {format(new Date(r.created_at), "HH:mm")}
                      </div>
                    </TableCell>

                    {/* Status Badge */}
                    <TableCell className="px-6 py-4 text-center">
                      <button
                        onClick={() => setSelectedRedemptionForView(r)}
                        className="focus:outline-none cursor-pointer"
                        title="Click to view details or manage status"
                      >
                        <Badge
                          className={cn(
                            "font-black uppercase text-[10px] tracking-wider px-2.5 py-1 cursor-pointer transition-all hover:opacity-80",
                            r.status === "pending" &&
                              "bg-orange-500/10 text-orange-600 hover:bg-orange-500/20 border border-orange-500/20",
                            r.status === "approved" &&
                              "bg-green-500/10 text-green-600 hover:bg-green-500/20 border border-green-500/20",
                            r.status === "rejected" &&
                              "bg-destructive/10 text-destructive hover:bg-destructive/20 border border-destructive/20",
                            r.status === "review_required" &&
                              "bg-red-500/10 text-red-600 hover:bg-red-500/20 animate-pulse border border-red-500/30",
                          )}
                        >
                          {r.status === "review_required" ? "Fraud Review" : r.status}
                        </Badge>
                      </button>
                    </TableCell>

                    {/* Direct Quick Confirm / Decline Actions */}
                    <TableCell className="px-6 py-4 text-right">
                      {isPending ? (
                        <div className="flex items-center justify-end gap-2">
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-8 px-2.5 rounded-lg text-destructive hover:text-destructive hover:bg-destructive/10 border-destructive/20 font-bold text-xs"
                            onClick={() => {
                              setSelectedRedemptionForDecline(r);
                              setRejectionReason("");
                            }}
                            disabled={updateStatusMutation.isPending}
                          >
                            <XCircle className="size-3.5 mr-1" />
                            Decline
                          </Button>
                          <Button
                            size="sm"
                            className="h-8 px-3 rounded-lg bg-green-600 hover:bg-green-700 text-white font-bold text-xs shadow-sm shadow-green-600/20"
                            onClick={() => setSelectedRedemptionForApprove(r)}
                            disabled={updateStatusMutation.isPending}
                          >
                            <CheckCircle2 className="size-3.5 mr-1" />
                            Confirm
                          </Button>
                        </div>
                      ) : (
                        <div className="flex items-center justify-end gap-2">
                          <Button
                            size="sm"
                            variant="ghost"
                            className="h-8 px-2.5 rounded-lg text-muted-foreground hover:text-foreground font-bold text-xs"
                            onClick={() => setSelectedRedemptionForView(r)}
                          >
                            <Eye className="size-3.5 mr-1" />
                            Details
                          </Button>
                        </div>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination */}
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

      {/* Dialog 1: Quick Confirm / Approve Dialog */}
      <AlertDialog
        open={!!selectedRedemptionForApprove}
        onOpenChange={(open) => !open && setSelectedRedemptionForApprove(null)}
      >
        <AlertDialogContent className="rounded-2xl border-border/50 max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle className="font-black text-xl flex items-center gap-2 text-green-600">
              <CheckCircle2 className="size-5 text-green-600" /> Confirm & Approve Redemption
            </AlertDialogTitle>
            <AlertDialogDescription className="text-sm font-medium space-y-3 pt-2">
              <div>
                Are you sure you want to approve the reward{" "}
                <span className="text-primary font-bold">
                  "{selectedRedemptionForApprove?.rewards?.title}"
                </span>{" "}
                for{" "}
                <span className="font-bold text-foreground">
                  {selectedRedemptionForApprove?.profiles?.full_name ||
                    selectedRedemptionForApprove?.profiles?.username ||
                    "this user"}
                </span>
                ?
              </div>

              {/* Destination check */}
              {selectedRedemptionForApprove?.wallet_address ? (
                <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/25 text-left space-y-1">
                  <div className="flex items-center justify-between text-xs font-bold text-amber-500">
                    <span className="flex items-center gap-1.5">
                      <Coins className="size-3.5" /> Payout Destination (USDT TRC20)
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        navigator.clipboard.writeText(selectedRedemptionForApprove.wallet_address);
                        toast.success("Wallet address copied!");
                      }}
                      className="hover:text-amber-400 p-0.5 cursor-pointer"
                    >
                      <Copy className="size-3.5" />
                    </button>
                  </div>
                  <div className="font-mono text-xs break-all select-all text-foreground font-semibold">
                    {selectedRedemptionForApprove.wallet_address}
                  </div>
                </div>
              ) : (
                <div className="p-3 rounded-xl bg-primary/10 border border-primary/25 text-left space-y-1">
                  <div className="flex items-center justify-between text-xs font-bold text-primary">
                    <span className="flex items-center gap-1.5">
                      <Mail className="size-3.5" /> Delivery Email
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        const emailToCopy =
                          selectedRedemptionForApprove?.delivery_email ||
                          selectedRedemptionForApprove?.profiles?.email ||
                          "";
                        navigator.clipboard.writeText(emailToCopy);
                        toast.success("Email address copied!");
                      }}
                      className="hover:text-primary/80 p-0.5 cursor-pointer"
                    >
                      <Copy className="size-3.5" />
                    </button>
                  </div>
                  <div className="font-mono text-xs break-all select-all text-foreground font-semibold">
                    {selectedRedemptionForApprove?.delivery_email ||
                      selectedRedemptionForApprove?.profiles?.email ||
                      "User registered email"}
                  </div>
                </div>
              )}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex gap-2 sm:gap-2">
            <AlertDialogCancel className="rounded-xl font-bold uppercase text-[10px] tracking-widest flex-1">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              className="rounded-xl font-bold uppercase text-[10px] tracking-widest bg-green-600 hover:bg-green-700 text-white flex-1"
              onClick={() => {
                if (!selectedRedemptionForApprove) return;
                updateStatusMutation.mutate({
                  id: selectedRedemptionForApprove.id,
                  status: "approved",
                  userId: selectedRedemptionForApprove.user_id,
                  rewardTitle: selectedRedemptionForApprove.rewards?.title || "Reward",
                });
              }}
              disabled={updateStatusMutation.isPending}
            >
              {updateStatusMutation.isPending ? (
                <Loader2 className="size-3.5 animate-spin mr-1" />
              ) : (
                <Check className="size-3.5 mr-1" />
              )}
              Confirm Approval
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Dialog 2: Decline / Reject Dialog with Reasons */}
      <AlertDialog
        open={!!selectedRedemptionForDecline}
        onOpenChange={(open) => !open && setSelectedRedemptionForDecline(null)}
      >
        <AlertDialogContent className="rounded-2xl border-border/50 max-w-md">
          <AlertDialogHeader>
            <AlertDialogTitle className="font-black text-xl flex items-center gap-2 text-destructive">
              <XCircle className="size-5 text-destructive" /> Decline Redemption
            </AlertDialogTitle>
            <AlertDialogDescription className="text-sm font-medium space-y-3 pt-2">
              <div>
                Declining this redemption will{" "}
                <span className="font-bold text-destructive">refund{" "}
                  {selectedRedemptionForDecline?.rewards?.cost_points?.toLocaleString() || 0} points
                </span>{" "}
                back to{" "}
                <span className="font-bold text-foreground">
                  {selectedRedemptionForDecline?.profiles?.full_name ||
                    selectedRedemptionForDecline?.profiles?.username ||
                    "the user"}
                </span>
                .
              </div>

              <div className="space-y-2 text-left">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                  Select or Enter Reason
                </label>
                <div className="flex flex-wrap gap-1.5">
                  {[
                    "Invalid TRC20 wallet address",
                    "Unreachable delivery email",
                    "Duplicate redemption request",
                    "Terms of service violation",
                  ].map((preset) => (
                    <button
                      key={preset}
                      type="button"
                      onClick={() => setRejectionReason(preset)}
                      className={cn(
                        "text-[10px] font-bold px-2.5 py-1 rounded-lg border transition-all",
                        rejectionReason === preset
                          ? "bg-destructive text-destructive-foreground border-destructive"
                          : "bg-muted/40 hover:bg-muted text-muted-foreground border-border/50",
                      )}
                    >
                      {preset}
                    </button>
                  ))}
                </div>
                <Input
                  placeholder="Type or customize reason for user..."
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  className="rounded-xl mt-2"
                />
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter className="flex gap-2 sm:gap-2">
            <AlertDialogCancel className="rounded-xl font-bold uppercase text-[10px] tracking-widest flex-1">
              Cancel
            </AlertDialogCancel>
            <AlertDialogAction
              className="rounded-xl font-bold uppercase text-[10px] tracking-widest bg-destructive hover:bg-destructive/90 text-white flex-1"
              onClick={() => {
                if (!selectedRedemptionForDecline) return;
                if (!rejectionReason.trim()) {
                  toast.error("Please provide a reason for declining.");
                  return;
                }
                updateStatusMutation.mutate({
                  id: selectedRedemptionForDecline.id,
                  status: "rejected",
                  userId: selectedRedemptionForDecline.user_id,
                  rewardTitle: selectedRedemptionForDecline.rewards?.title || "Reward",
                  reason: rejectionReason,
                });
              }}
              disabled={updateStatusMutation.isPending || !rejectionReason.trim()}
            >
              {updateStatusMutation.isPending ? (
                <Loader2 className="size-3.5 animate-spin mr-1" />
              ) : (
                <X className="size-3.5 mr-1" />
              )}
              Confirm Decline & Refund
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Dialog 3: Full Redemption Details & Status Management Dialog */}
      <AlertDialog
        open={!!selectedRedemptionForView}
        onOpenChange={(open) => !open && setSelectedRedemptionForView(null)}
      >
        <AlertDialogContent className="rounded-2xl border-border/50 max-w-lg">
          <AlertDialogHeader>
            <AlertDialogTitle className="font-black text-xl flex items-center justify-between">
              <span>Redemption Details</span>
              <Badge
                className={cn(
                  "font-black uppercase text-[10px] tracking-wider px-2 py-0.5",
                  selectedRedemptionForView?.status === "pending" &&
                    "bg-orange-500/10 text-orange-600",
                  selectedRedemptionForView?.status === "approved" &&
                    "bg-green-500/10 text-green-600",
                  selectedRedemptionForView?.status === "rejected" &&
                    "bg-destructive/10 text-destructive",
                  selectedRedemptionForView?.status === "review_required" &&
                    "bg-red-500/10 text-red-600 animate-pulse",
                )}
              >
                {selectedRedemptionForView?.status}
              </Badge>
            </AlertDialogTitle>
            <div className="font-medium text-sm space-y-4 text-muted-foreground pt-2 text-left">
              {/* Reward & Cost Box */}
              <div className="p-3.5 rounded-xl bg-muted/40 border border-border/50 space-y-1">
                <div className="flex items-center justify-between">
                  <span className="font-black text-foreground text-base">
                    {selectedRedemptionForView?.rewards?.title}
                  </span>
                  <Badge variant="outline" className="font-bold text-primary">
                    {selectedRedemptionForView?.rewards?.cost_points?.toLocaleString()} points
                  </Badge>
                </div>
                <div className="text-xs text-muted-foreground flex items-center gap-2">
                  <span>Category: {selectedRedemptionForView?.rewards?.category || "Reward"}</span>
                  <span>•</span>
                  <span>
                    Requested:{" "}
                    {selectedRedemptionForView?.created_at &&
                      format(new Date(selectedRedemptionForView.created_at), "MMM d, yyyy HH:mm")}
                  </span>
                </div>
              </div>

              {/* User Details */}
              <div className="p-3.5 rounded-xl bg-muted/40 border border-border/50 space-y-1.5">
                <div className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                  User Details
                </div>
                <div className="font-bold text-foreground">
                  {selectedRedemptionForView?.profiles?.full_name ||
                    selectedRedemptionForView?.profiles?.username ||
                    "User"}
                </div>
                <div className="text-xs text-muted-foreground">
                  {selectedRedemptionForView?.profiles?.email}
                </div>
                {selectedRedemptionForView?.profiles?.phone_number && (
                  <div className="text-xs text-emerald-600 font-semibold">
                    Phone: {selectedRedemptionForView.profiles.phone_number}
                  </div>
                )}
                <div className="flex flex-wrap gap-2 pt-1">
                  {selectedRedemptionForView?.profiles?.twitter_handle && (
                    <span className="text-[10px] font-bold text-sky-500 bg-sky-500/10 px-2 py-0.5 rounded">
                      𝕏 @{selectedRedemptionForView.profiles.twitter_handle.replace(/^@/, "")}
                    </span>
                  )}
                  {selectedRedemptionForView?.profiles?.telegram_handle && (
                    <span className="text-[10px] font-bold text-blue-500 bg-blue-500/10 px-2 py-0.5 rounded">
                      ✈ @{selectedRedemptionForView.profiles.telegram_handle.replace(/^@/, "")}
                    </span>
                  )}
                </div>
              </div>

              {/* Payout Destination Info Box */}
              {selectedRedemptionForView?.wallet_address ? (
                <div className="p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/25 space-y-1">
                  <div className="flex items-center justify-between text-xs font-bold text-amber-500">
                    <span className="flex items-center gap-1.5">
                      <Coins className="size-3.5" /> Payout Destination (USDT TRC20)
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        navigator.clipboard.writeText(selectedRedemptionForView.wallet_address);
                        toast.success("Wallet address copied!");
                      }}
                      className="hover:text-amber-400 p-0.5 cursor-pointer"
                    >
                      <Copy className="size-3.5" />
                    </button>
                  </div>
                  <div className="font-mono text-xs break-all select-all text-foreground font-semibold">
                    {selectedRedemptionForView.wallet_address}
                  </div>
                </div>
              ) : (
                <div className="p-3.5 rounded-xl bg-primary/10 border border-primary/25 space-y-1">
                  <div className="flex items-center justify-between text-xs font-bold text-primary">
                    <span className="flex items-center gap-1.5">
                      <Mail className="size-3.5" /> Delivery Destination (Email)
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        const emailToCopy =
                          selectedRedemptionForView?.delivery_email ||
                          selectedRedemptionForView?.profiles?.email ||
                          "";
                        navigator.clipboard.writeText(emailToCopy);
                        toast.success("Email address copied!");
                      }}
                      className="hover:text-primary/80 p-0.5 cursor-pointer"
                    >
                      <Copy className="size-3.5" />
                    </button>
                  </div>
                  <div className="font-mono text-xs break-all select-all text-foreground font-semibold">
                    {selectedRedemptionForView?.delivery_email ||
                      selectedRedemptionForView?.profiles?.email ||
                      "User registered email"}
                  </div>
                </div>
              )}

              {selectedRedemptionForView?.rejection_reason && (
                <div className="p-3 rounded-xl bg-destructive/10 border border-destructive/20 text-xs">
                  <span className="font-black uppercase tracking-wider text-destructive block mb-1">
                    Rejection Reason
                  </span>
                  <p className="text-foreground">{selectedRedemptionForView.rejection_reason}</p>
                </div>
              )}

              {/* Status Update Actions */}
              <div className="space-y-2 pt-2">
                <div className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                  Change Status
                </div>
                <div className="flex flex-col gap-2">
                  <Button
                    className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest bg-green-600 hover:bg-green-700 text-white"
                    onClick={() => {
                      updateStatusMutation.mutate({
                        id: selectedRedemptionForView.id,
                        status: "approved",
                        userId: selectedRedemptionForView.user_id,
                        rewardTitle: selectedRedemptionForView.rewards?.title || "Reward",
                      });
                    }}
                    disabled={
                      selectedRedemptionForView?.status === "approved" ||
                      updateStatusMutation.isPending
                    }
                  >
                    <Check className="mr-2 h-4 w-4" /> Approve Redemption
                  </Button>

                  <Button
                    variant="destructive"
                    className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest"
                    onClick={() => {
                      const item = selectedRedemptionForView;
                      setSelectedRedemptionForView(null);
                      setSelectedRedemptionForDecline(item);
                    }}
                    disabled={
                      selectedRedemptionForView?.status === "rejected" ||
                      updateStatusMutation.isPending
                    }
                  >
                    <X className="mr-2 h-4 w-4" /> Decline / Reject Redemption
                  </Button>

                  {selectedRedemptionForView?.status !== "pending" && (
                    <Button
                      variant="outline"
                      className="w-full justify-start rounded-xl font-bold uppercase text-[10px] tracking-widest"
                      onClick={() => {
                        updateStatusMutation.mutate({
                          id: selectedRedemptionForView.id,
                          status: "pending",
                          userId: selectedRedemptionForView.user_id,
                          rewardTitle: selectedRedemptionForView.rewards?.title || "Reward",
                        });
                      }}
                      disabled={updateStatusMutation.isPending}
                    >
                      <Loader2 className="mr-2 h-4 w-4" /> Reset to Pending
                    </Button>
                  )}
                </div>
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
    </div>
  );
}
