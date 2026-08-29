import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { AnalyticsView } from "./AnalyticsView";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  User,
  Loader2,
  Mail,
  Settings2,
  RefreshCw,
  Plus,
  Minus,
  AlertCircle,
  Search,
  Calendar,
  ChevronLeft,
  ChevronRight,
  Filter,
} from "lucide-react";
import { useState, useMemo, useEffect } from "react";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { format, subDays, startOfDay, endOfDay } from "date-fns";
import { cn } from "@/lib/utils";
import { adjustUserPoints } from "@/lib/admin-points.functions";
import { useServerFn } from "@tanstack/react-start";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export function ReferralsManager() {
  const queryClient = useQueryClient();
  const adjustPointsFn = useServerFn(adjustUserPoints);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [adjustAmount, setAdjustAmount] = useState<string>("0");
  const [adjustType, setAdjustType] = useState<"earn" | "redemption">("earn");
  const [adjustDescription, setAdjustDescription] = useState<string>("Referral points adjustment");

  const [searchQuery, setSearchQuery] = useState("");
  const [timeFilter, setTimeFilter] = useState("all");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  useEffect(() => {
    const channel = supabase
      .channel("admin-referrals-realtime")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "referrals",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["admin-referral-events"] });
          queryClient.invalidateQueries({ queryKey: ["funnelAnalytics"] });
          queryClient.invalidateQueries({ queryKey: ["adminStats"] });
          toast.success("New referral recorded in system");
        },
      )
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "profiles",
        },
        (payload) => {
          // If a user completes profile, metrics might change
          if (
            payload.new["has_claimed_welcome_bonus"] !== payload.old["has_claimed_welcome_bonus"]
          ) {
            queryClient.invalidateQueries({ queryKey: ["admin-referral-events"] });
            queryClient.invalidateQueries({ queryKey: ["funnelAnalytics"] });
            queryClient.invalidateQueries({ queryKey: ["adminStats"] });
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  const { data, isLoading } = useQuery({
    queryKey: ["admin-referral-events", timeFilter, searchQuery, currentPage],
    queryFn: async () => {
      let query = supabase.from("referrals_with_profiles").select(`*`, { count: "exact" });

      if (timeFilter !== "all") {
        const days = parseInt(timeFilter);
        const startDate = subDays(new Date(), days).toISOString();
        query = query.gte("created_at", startDate);
      }

      if (searchQuery) {
        // Since we are searching across joins, we'll use or() with proper references
        const search = `%${searchQuery}%`;
        query = query.or(`referrer_username.ilike.${search},referee_username.ilike.${search}`);
      }

      const from = (currentPage - 1) * itemsPerPage;
      const to = from + itemsPerPage - 1;

      const { data, count, error } = await query
        .order("created_at", { ascending: false })
        .range(from, to);

      if (error) throw error;
      return { events: data || [], totalCount: count || 0 };
    },
  });

  const referralEvents = data?.events || [];
  const totalCount = data?.totalCount || 0;
  const totalPages = Math.ceil(totalCount / itemsPerPage);

  const paginatedEvents = referralEvents;

  const adjustPointsMutation = useMutation({
    mutationFn: async ({ userId, amount, description }: any) => {
      await adjustPointsFn({
        data: {
          userId,
          amount: Math.abs(amount),
          actionType: amount >= 0 ? "credit" : "debit",
          reason: description,
        },
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-referrals-users"] });
      queryClient.invalidateQueries({ queryKey: ["adminStats"] });
      toast.success("Points adjusted successfully");
      setSelectedUser(null);
      setAdjustAmount("0");
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to adjust points");
    },
  });

  const resendNotificationMutation = useMutation({
    mutationFn: async (userId: string) => {
      const { data, error } = await supabase.rpc("send_user_notification", {
        _user_id: userId,
        _title: "Referral Validation",
        _message:
          "Your referral code has been validated. You can now track your progress in the Referral Dashboard.",
        _type: "referral",
      });

      if (error) throw error;
      if (data && (data as any).success === false)
        throw new Error((data as any).message || "Failed to send notification");
    },
    onSuccess: () => {
      toast.success("Validation notification sent");
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to send notification");
    },
  });

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      <AnalyticsView />
      <div className="space-y-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 px-1">
          <div>
            <h3 className="text-xl font-black uppercase tracking-tight">Referral Events</h3>
            <p className="text-sm text-muted-foreground font-medium">
              Review invites and adjust rewards.
            </p>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3 w-full md:w-auto">
            <div className="relative w-full sm:w-64">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search users..."
                value={searchQuery}
                onChange={(e) => {
                  setSearchQuery(e.target.value);
                  setCurrentPage(1);
                }}
                className="pl-9 rounded-xl border-border/50 h-10 font-medium"
              />
            </div>

            <div className="flex items-center gap-2 bg-card border border-border/50 rounded-xl px-3 py-1.5 w-full sm:w-auto">
              <Calendar className="h-4 w-4 text-muted-foreground" />
              <Select
                value={timeFilter}
                onValueChange={(val) => {
                  setTimeFilter(val);
                  setCurrentPage(1);
                }}
              >
                <SelectTrigger className="border-none bg-transparent h-7 w-[110px] focus:ring-0 font-bold text-xs uppercase tracking-widest">
                  <SelectValue placeholder="All Time" />
                </SelectTrigger>
                <SelectContent className="rounded-xl border-border/50">
                  <SelectItem value="all" className="text-xs font-bold uppercase tracking-widest">
                    All Time
                  </SelectItem>
                  <SelectItem value="1" className="text-xs font-bold uppercase tracking-widest">
                    Last 24h
                  </SelectItem>
                  <SelectItem value="7" className="text-xs font-bold uppercase tracking-widest">
                    Last 7 Days
                  </SelectItem>
                  <SelectItem value="30" className="text-xs font-bold uppercase tracking-widest">
                    Last 30 Days
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>

        <div className="rounded-2xl border border-border/50 bg-card overflow-hidden overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent border-border/50">
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[150px]">
                  Referrer (Inviter)
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[150px]">
                  Referee (New User)
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                  Status
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-right">
                  Actions
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {paginatedEvents.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={4}
                    className="h-32 text-center text-muted-foreground font-medium"
                  >
                    No referral events found.
                  </TableCell>
                </TableRow>
              ) : (
                paginatedEvents.map((event: any) => (
                  <TableRow
                    key={`${event.referrer_id}-${event.referee_id}`}
                    className="border-border/40 hover:bg-accent/5 transition-colors"
                  >
                    <TableCell className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <Avatar className="h-8 w-8 border border-border shadow-sm">
                          <AvatarImage src={event.referrer?.avatar_url || ""} />
                          <AvatarFallback className="bg-primary/5 text-primary text-[10px]">
                            <User className="h-3 w-3" />
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <div className="font-bold flex items-center gap-2 text-sm">
                            {event.referrer?.username || "Unknown"}
                          </div>
                          <div className="text-[10px] text-muted-foreground font-bold uppercase tracking-wider">
                            {event.referrer?.referral_code || "No Code"}
                          </div>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="px-6 py-4">
                      <div className="space-y-0.5">
                        <div className="font-bold text-sm">
                          {event.referee?.username ||
                            event.referee?.email?.split("@")[0] ||
                            "New User"}
                        </div>
                        <div className="text-[10px] text-muted-foreground font-medium">
                          Joined{" "}
                          {format(
                            new Date(event.created_at || event.referee?.created_at),
                            "MMM d, yyyy",
                          )}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      {event.referee?.has_claimed_welcome_bonus ? (
                        <Badge
                          variant="outline"
                          className="font-black text-green-600 border-green-600/20 bg-green-500/5 uppercase text-[9px] tracking-widest"
                        >
                          Completed
                        </Badge>
                      ) : (
                        <div className="flex flex-col items-center gap-1">
                          <Badge
                            variant="outline"
                            className="font-black text-amber-600 border-amber-600/20 bg-amber-500/5 uppercase text-[9px] tracking-widest"
                          >
                            Pending Socials
                          </Badge>
                          <div className="flex gap-1">
                            <Badge
                              variant="outline"
                              className={cn(
                                "text-[8px] px-1 border-none",
                                event.referee?.twitter_handle
                                  ? "text-green-600 bg-green-50"
                                  : "text-red-400 bg-red-50",
                              )}
                            >
                              TW
                            </Badge>
                            <Badge
                              variant="outline"
                              className={cn(
                                "text-[8px] px-1 border-none",
                                event.referee?.telegram_handle
                                  ? "text-green-600 bg-green-50"
                                  : "text-red-400 bg-red-50",
                              )}
                            >
                              TG
                            </Badge>
                          </div>
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="px-6 py-4 text-right">
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-muted-foreground hover:text-primary hover:bg-primary/5 transition-colors"
                          title="Adjust Referrer Points"
                          onClick={() => setSelectedUser(event.referrer)}
                        >
                          <Settings2 className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-muted-foreground hover:text-blue-500 hover:bg-blue-50 transition-colors"
                          title="Resend Reward Notification"
                          onClick={() => resendNotificationMutation.mutate(event.referrer_id)}
                        >
                          <RefreshCw className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>

          {totalPages > 1 && (
            <div className="flex items-center justify-between px-6 py-4 border-t border-border/40">
              <p className="text-[10px] font-bold text-muted-foreground uppercase tracking-widest">
                Showing {(currentPage - 1) * itemsPerPage + 1} to{" "}
                {Math.min(currentPage * itemsPerPage, totalCount)} of {totalCount} entries
              </p>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  className="rounded-xl h-8 px-3 font-bold border-border/50 text-[10px]"
                  disabled={currentPage === 1}
                  onClick={() => setCurrentPage((prev) => prev - 1)}
                >
                  <ChevronLeft className="h-3 w-3 mr-1" />
                  PREV
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  className="rounded-xl h-8 px-3 font-bold border-border/50 text-[10px]"
                  disabled={currentPage === totalPages}
                  onClick={() => setCurrentPage((prev) => prev + 1)}
                >
                  NEXT
                  <ChevronRight className="h-3 w-3 ml-1" />
                </Button>
              </div>
            </div>
          )}
        </div>

        <Dialog open={!!selectedUser} onOpenChange={(open) => !open && setSelectedUser(null)}>
          <DialogContent className="sm:max-w-[425px] rounded-[2rem]">
            <DialogHeader>
              <DialogTitle className="text-2xl font-black">Adjust Points</DialogTitle>
              <DialogDescription className="font-medium">
                Manually adjust points for{" "}
                <span className="text-foreground font-bold">
                  {selectedUser?.username || "this user"}
                </span>
                .
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-6 py-4">
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Type
                </label>
                <div className="grid grid-cols-2 gap-2">
                  <Button
                    type="button"
                    variant={adjustType === "earn" ? "default" : "outline"}
                    className="rounded-xl font-bold"
                    onClick={() => setAdjustType("earn")}
                  >
                    <Plus className="h-4 w-4 mr-2" />
                    Add Points
                  </Button>
                  <Button
                    type="button"
                    variant={adjustType === "redemption" ? "default" : "outline"}
                    className="rounded-xl font-bold"
                    onClick={() => setAdjustType("redemption")}
                  >
                    <Minus className="h-4 w-4 mr-2" />
                    Deduct
                  </Button>
                </div>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Amount
                </label>
                <Input
                  type="number"
                  value={adjustAmount}
                  onChange={(e) => setAdjustAmount(e.target.value)}
                  className="rounded-xl border-border/50 h-11 font-bold"
                  placeholder="Enter amount..."
                />
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Description
                </label>
                <Input
                  value={adjustDescription}
                  onChange={(e) => setAdjustDescription(e.target.value)}
                  className="rounded-xl border-border/50 h-11 font-bold"
                  placeholder="Reason for adjustment..."
                />
              </div>

              <div className="p-4 rounded-xl bg-amber-50 border border-amber-100 flex gap-3">
                <AlertCircle className="h-5 w-5 text-amber-500 shrink-0" />
                <p className="text-[10px] text-amber-800 font-medium">
                  This will create a transaction record and update the user's balance instantly.
                </p>
              </div>
            </div>

            <DialogFooter>
              <Button
                className="w-full rounded-xl font-bold h-12 shadow-lg shadow-primary/10"
                disabled={adjustPointsMutation.isPending || !adjustAmount || adjustAmount === "0"}
                onClick={() =>
                  adjustPointsMutation.mutate({
                    userId: selectedUser.id,
                    amount:
                      adjustType === "earn"
                        ? parseInt(adjustAmount)
                        : -Math.abs(parseInt(adjustAmount)),
                    type: adjustType,
                    description: adjustDescription,
                  })
                }
              >
                {adjustPointsMutation.isPending ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Updating...
                  </>
                ) : (
                  "Save Adjustment"
                )}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}
