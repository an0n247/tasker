"use client";
import React, { useState, useEffect } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
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
  Mail,
  ShieldAlert,
  Eye,
  TrendingUp,
  Gift,
  Users as UsersIcon,
  Calendar,
  Phone,
  Hash,
  Search,
  Filter,
  ChevronLeft,
  ChevronRight,
  Shield,
  Plus,
  Minus,
  Coins,
  Loader2,
} from "lucide-react";
import { format } from "date-fns";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { assignUserRole } from "@/lib/admin.functions";
import { adjustUserPoints } from "@/lib/admin-points.functions";
import { toast } from "sonner";
import { useServerFn } from "@tanstack/react-start";

export function UsersManager() {
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [currentPage, setCurrentPage] = useState(1);
  const [pointAction, setPointAction] = useState<{
    amount: string;
    reason: string;
    type: "credit" | "debit";
  }>({ amount: "", reason: "", type: "credit" });
  const [isAdjusting, setIsAdjusting] = useState(false);
  const itemsPerPage = 10;
  const queryClient = useQueryClient();
  const assignRoleFn = useServerFn(assignUserRole);
  const adjustPointsFn = useServerFn(adjustUserPoints);

  const handleAdjustPoints = async () => {
    if (!selectedUser || !pointAction.amount || !pointAction.reason) {
      toast.error("Please fill in all fields");
      return;
    }

    setIsAdjusting(true);
    try {
      await adjustPointsFn({
        data: {
          userId: selectedUser.id,
          amount: parseInt(pointAction.amount),
          reason: pointAction.reason,
          actionType: pointAction.type,
        },
      });
      toast.success(`Successfully ${pointAction.type}ed points`);
      setPointAction({ amount: "", reason: "", type: "credit" });
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      queryClient.invalidateQueries({ queryKey: ["user-details", selectedUser.id] });
      queryClient.invalidateQueries({ queryKey: ["admin-points-audit-logs"] });
    } catch (err: any) {
      toast.error(err.message || "Failed to adjust points");
    } finally {
      setIsAdjusting(false);
    }
  };

  const { data, isLoading } = useQuery({
    queryKey: ["admin-users", searchQuery, roleFilter, currentPage],
    queryFn: async () => {
      let query = supabase.from("profiles").select("*", { count: "exact" });
      if (searchQuery) {
        query = query.or(
          `username.ilike.%${searchQuery}%,email.ilike.%${searchQuery}%,full_name.ilike.%${searchQuery}%`,
        );
      }
      const from = (currentPage - 1) * itemsPerPage;
      const to = from + itemsPerPage - 1;
      const {
        data: profiles,
        count,
        error: profilesError,
      } = await query.order("created_at", { ascending: false }).range(from, to);
      if (profilesError) throw profilesError;
      const { data: roles, error: rolesError } = await supabase
        .from("user_roles")
        .select("user_id, role")
        .in(
          "user_id",
          profiles.map((p) => p.id),
        );
      if (rolesError) throw rolesError;
      const mappedUsers = profiles.map((profile) => ({
        ...profile,
        isAdmin: roles?.some((r) => r.user_id === profile.id && r.role === "admin"),
        isModerator: roles?.some((r) => r.user_id === profile.id && r.role === "moderator"),
        isTaskManager: roles?.some((r) => r.user_id === profile.id && r.role === "task_manager"),
        currentRole: roles?.find((r) => r.user_id === profile.id)?.role || "user",
      }));
      let finalUsers = mappedUsers;
      if (roleFilter !== "all") {
        finalUsers = mappedUsers.filter(
          (user) =>
            (roleFilter === "admin" && user.isAdmin) || (roleFilter === "user" && !user.isAdmin),
        );
      }
      return { users: finalUsers, totalCount: count || 0 };
    },
  });

  const handleRoleChange = async (uid: string, r: string) => {
    try {
      await assignRoleFn({ data: { userId: uid, role: r as any } });
      queryClient.invalidateQueries({ queryKey: ["admin-users"] });
      toast.success("User role updated successfully");
    } catch (err: any) {
      toast.error(err.message || "Failed to update user role");
    }
  };

  const users = data?.users || [];
  const totalCount = data?.totalCount || 0;
  const totalPages = Math.ceil(totalCount / itemsPerPage);

  const { data: userDetails, isLoading: isDetailsLoading } = useQuery({
    queryKey: ["user-details", selectedUser?.id],
    queryFn: async () => {
      if (!selectedUser) return null;
      const [txs, refs, reds, stats] = await Promise.all([
        supabase
          .from("points_transactions")
          .select("*")
          .eq("user_id", selectedUser.id)
          .order("created_at", { ascending: false }),
        supabase
          .from("referrals")
          .select("*, profiles!referrals_referee_id_fkey(username, full_name, email)")
          .eq("referrer_id", selectedUser.id)
          .order("created_at", { ascending: false }),
        supabase
          .from("redemptions")
          .select("*, rewards(title, cost_points)")
          .eq("user_id", selectedUser.id)
          .order("created_at", { ascending: false }),
        supabase
          .from("referral_stats_summary")
          .select("total_referrals")
          .eq("user_id", selectedUser.id)
          .maybeSingle(),
      ]);
      return {
        transactions: txs.data || [],
        referrals: refs.data || [],
        redemptions: reds.data || [],
        referralCount: stats.data?.total_referrals || 0,
      };
    },
    enabled: !!selectedUser && isDetailsOpen,
  });

  if (isLoading) {
    return (
      <div className="flex justify-center p-12">
        <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
        <div className="relative w-full md:w-96">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search users..."
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setCurrentPage(1);
            }}
            className="pl-10 rounded-xl h-11"
          />
        </div>
        <div className="flex items-center gap-3">
          <Select
            value={roleFilter}
            onValueChange={(val) => {
              setRoleFilter(val);
              setCurrentPage(1);
            }}
          >
            <SelectTrigger className="w-[140px] rounded-xl">
              <SelectValue placeholder="All Roles" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Roles</SelectItem>
              <SelectItem value="admin">Admins</SelectItem>
              <SelectItem value="user">Users</SelectItem>
            </SelectContent>
          </Select>
          <Badge variant="secondary" className="h-11 px-4 rounded-xl">
            {totalCount} Users
          </Badge>
        </div>
      </div>
      <div className="rounded-2xl border bg-card overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>User</TableHead>
              <TableHead>Contact</TableHead>
              <TableHead>Balance</TableHead>
              <TableHead>Joined</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {users.map((user) => (
              <TableRow key={user.id}>
                <TableCell>
                  <div className="flex items-center gap-3">
                    <Avatar className="h-8 w-8">
                      <AvatarImage src={user.avatar_url || ""} />
                      <AvatarFallback>
                        <User className="h-3 w-3" />
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <div className="font-bold flex items-center gap-2">
                        {user.username || "User"}{" "}
                        {user.isAdmin && <ShieldAlert className="h-3 w-3 text-primary" />}
                      </div>
                      <div className="text-xs text-muted-foreground">{user.full_name}</div>
                    </div>
                  </div>
                </TableCell>
                <TableCell>
                  <div className="text-xs">{user.email}</div>
                </TableCell>
                <TableCell>
                  <Badge variant="outline">{user.points_balance || 0} pts</Badge>
                </TableCell>
                <TableCell className="text-xs">
                  {format(new Date(user.created_at), "MMM d, yyyy")}
                </TableCell>
                <TableCell className="text-right">
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => {
                      setSelectedUser(user);
                      setIsDetailsOpen(true);
                    }}
                  >
                    <Eye className="h-4 w-4" />
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      <Dialog open={isDetailsOpen} onOpenChange={setIsDetailsOpen}>
        <DialogContent className="max-w-4xl w-[95vw] sm:w-full max-h-[90vh] overflow-y-auto rounded-[2rem] p-4 sm:p-8">
          <DialogHeader>
            <div className="flex items-center gap-4 mb-4">
              <Avatar className="h-16 w-16 border-2 border-primary/20">
                <AvatarImage src={selectedUser?.avatar_url || ""} />
                <AvatarFallback className="bg-primary/5">
                  <User className="h-8 w-8 text-primary/40" />
                </AvatarFallback>
              </Avatar>
              <div>
                <DialogTitle className="text-2xl font-black uppercase tracking-tight">
                  {selectedUser?.username || "User Details"}
                </DialogTitle>
                <div className="flex items-center gap-2 text-muted-foreground font-medium">
                  <Mail className="h-4 w-4" />
                  <span>{selectedUser?.email}</span>
                </div>
              </div>
            </div>
          </DialogHeader>

          {selectedUser && (
            <div className="space-y-8 py-4">
              {/* Account Overview Grid */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card className="bg-accent/5 border-none shadow-none md:block hidden">
                  <CardContent className="pt-6">
                    <div className="flex flex-col items-center text-center">
                      <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center mb-3">
                        <Gift className="h-5 w-5 text-primary" />
                      </div>
                      <span className="text-xs font-black uppercase text-muted-foreground mb-1">
                        Total Points
                      </span>
                      <span className="text-2xl font-black">
                        {selectedUser.points_balance || 0}
                      </span>
                    </div>
                  </CardContent>
                </Card>

                <Card className="bg-accent/5 border-none shadow-none md:block hidden">
                  <CardContent className="pt-6">
                    <div className="flex flex-col items-center text-center">
                      <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center mb-3">
                        <UsersIcon className="h-5 w-5 text-primary" />
                      </div>
                      <span className="text-xs font-black uppercase text-muted-foreground mb-1">
                        Referrals
                      </span>
                      <span className="text-2xl font-black">{userDetails?.referralCount || 0}</span>
                    </div>
                  </CardContent>
                </Card>

                <Card className="bg-accent/5 border-none shadow-none md:block hidden">
                  <CardContent className="pt-6">
                    <div className="flex flex-col items-center text-center">
                      <div className="h-10 w-10 rounded-full bg-primary/10 flex items-center justify-center mb-3">
                        <Calendar className="h-5 w-5 text-primary" />
                      </div>
                      <span className="text-xs font-black uppercase text-muted-foreground mb-1">
                        Joined
                      </span>
                      <span className="text-sm font-bold">
                        {selectedUser.created_at
                          ? format(new Date(selectedUser.created_at), "MMM d, yyyy")
                          : "N/A"}
                      </span>
                    </div>
                  </CardContent>
                </Card>

                {/* Mobile version: Single row for icons */}
                <div className="md:hidden flex items-center justify-around bg-accent/5 p-4 rounded-2xl border border-border/50">
                  <div className="flex flex-col items-center gap-1">
                    <Gift className="h-5 w-5 text-primary" />
                    <span className="text-[10px] font-black uppercase text-muted-foreground">
                      Points
                    </span>
                    <span className="text-sm font-black">{selectedUser.points_balance || 0}</span>
                  </div>
                  <div className="w-px h-8 bg-border/50" />
                  <div className="flex flex-col items-center gap-1">
                    <UsersIcon className="h-5 w-5 text-primary" />
                    <span className="text-[10px] font-black uppercase text-muted-foreground">
                      Refs
                    </span>
                    <span className="text-sm font-black">{userDetails?.referralCount || 0}</span>
                  </div>
                  <div className="w-px h-8 bg-border/50" />
                  <div className="flex flex-col items-center gap-1">
                    <Calendar className="h-5 w-5 text-primary" />
                    <span className="text-[10px] font-black uppercase text-muted-foreground">
                      Joined
                    </span>
                    <span className="text-xs font-bold">
                      {selectedUser.created_at
                        ? format(new Date(selectedUser.created_at), "MMM d, yy")
                        : "N/A"}
                    </span>
                  </div>
                </div>
              </div>

              {/* Personal Info & Role */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <h3 className="text-sm font-black uppercase flex items-center gap-2">
                    <User className="h-4 w-4" /> Personal Information
                  </h3>
                  <div className="space-y-3 bg-accent/5 p-4 rounded-2xl border border-border/50">
                    <div className="flex justify-between items-center">
                      <span className="text-xs font-bold text-muted-foreground">Full Name</span>
                      <span className="text-sm font-black">{selectedUser.full_name || "N/A"}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-xs font-bold text-muted-foreground">Username</span>
                      <span className="text-sm font-black">@{selectedUser.username}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className="text-xs font-bold text-muted-foreground">User ID</span>
                      <span className="text-[10px] font-mono opacity-50">{selectedUser.id}</span>
                    </div>
                  </div>
                </div>

                <div className="space-y-4">
                  <h3 className="text-sm font-black uppercase flex items-center gap-2 text-primary">
                    <Shield className="h-4 w-4" /> Access Management
                  </h3>
                  <div className="space-y-3 bg-primary/5 p-4 rounded-2xl border border-primary/20">
                    <div className="flex flex-col gap-2">
                      <span className="text-xs font-bold text-muted-foreground">Current Role</span>
                      <Select
                        defaultValue={selectedUser.currentRole}
                        onValueChange={(val) => handleRoleChange(selectedUser.id, val)}
                      >
                        <SelectTrigger className="w-full rounded-xl bg-background border-primary/20 h-10">
                          <SelectValue placeholder="Select Role" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="user">Standard User</SelectItem>
                          <SelectItem value="moderator">Moderator</SelectItem>
                          <SelectItem value="admin">Administrator</SelectItem>
                          <SelectItem value="task_manager">Task Manager</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                </div>
              </div>

              {/* Point Adjustment Section */}
              <div className="space-y-4">
                <h3 className="text-sm font-black uppercase flex items-center gap-2 text-green-600">
                  <Coins className="h-4 w-4" /> Point Adjustment
                </h3>
                <div className="space-y-3 bg-green-500/5 p-4 rounded-2xl border border-green-500/20">
                  <div className="grid grid-cols-2 gap-2">
                    <Button
                      variant={pointAction.type === "credit" ? "default" : "outline"}
                      className={cn(
                        "rounded-xl text-[10px] font-black uppercase",
                        pointAction.type === "credit" && "bg-green-600 hover:bg-green-700",
                      )}
                      onClick={() => setPointAction((prev) => ({ ...prev, type: "credit" }))}
                    >
                      <Plus className="h-3 w-3 mr-1" /> Credit
                    </Button>
                    <Button
                      variant={pointAction.type === "debit" ? "default" : "outline"}
                      className={cn(
                        "rounded-xl text-[10px] font-black uppercase",
                        pointAction.type === "debit" && "bg-destructive hover:bg-destructive/90",
                      )}
                      onClick={() => setPointAction((prev) => ({ ...prev, type: "debit" }))}
                    >
                      <Minus className="h-3 w-3 mr-1" /> Debit
                    </Button>
                  </div>
                  <Input
                    type="number"
                    placeholder="Amount"
                    value={pointAction.amount}
                    onChange={(e) =>
                      setPointAction((prev) => ({ ...prev, amount: e.target.value }))
                    }
                    className="rounded-xl border-green-500/20 bg-background h-10"
                  />
                  <Input
                    placeholder="Reason (e.g., Event reward)"
                    value={pointAction.reason}
                    onChange={(e) =>
                      setPointAction((prev) => ({ ...prev, reason: e.target.value }))
                    }
                    className="rounded-xl border-green-500/20 bg-background h-10"
                  />
                  <Button
                    className="w-full rounded-xl font-black uppercase text-[10px] tracking-widest h-10 shadow-lg shadow-green-500/10"
                    disabled={isAdjusting}
                    onClick={handleAdjustPoints}
                  >
                    {isAdjusting ? <Loader2 className="h-3 w-3 animate-spin mr-2" /> : null}
                    Confirm Adjustment
                  </Button>
                </div>
              </div>

              {/* Activity Lists */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <Card className="border-border/50 shadow-none">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-xs uppercase font-black flex items-center gap-2">
                      <TrendingUp className="h-4 w-4" /> Recent Transactions
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="h-64 overflow-y-auto no-scrollbar">
                    {isDetailsLoading ? (
                      <div className="flex justify-center py-8">
                        <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                      </div>
                    ) : userDetails?.transactions.length ? (
                      <div className="space-y-2">
                        {userDetails.transactions.map((tx: any) => (
                          <div
                            key={tx.id}
                            className="text-xs p-3 rounded-xl border border-border/50 flex justify-between items-center bg-accent/5"
                          >
                            <div className="flex flex-col gap-1">
                              <span className="font-bold">{tx.description}</span>
                              <span className="text-[10px] opacity-60">
                                {format(new Date(tx.created_at), "MMM d, HH:mm")}
                              </span>
                            </div>
                            <span
                              className={cn(
                                "font-black text-sm",
                                tx.amount > 0 ? "text-green-600" : "text-destructive",
                              )}
                            >
                              {tx.amount > 0 ? "+" : ""}
                              {tx.amount}
                            </span>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="text-center py-8 text-xs text-muted-foreground">
                        No transactions yet
                      </div>
                    )}
                  </CardContent>
                </Card>

                <Card className="border-border/50 shadow-none">
                  <CardHeader className="pb-2">
                    <CardTitle className="text-xs uppercase font-black flex items-center gap-2">
                      <UsersIcon className="h-4 w-4" /> Referrals
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="h-64 overflow-y-auto no-scrollbar">
                    {isDetailsLoading ? (
                      <div className="flex justify-center py-8">
                        <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                      </div>
                    ) : userDetails?.referrals.length ? (
                      <div className="space-y-2">
                        {userDetails.referrals.map((ref: any) => (
                          <div
                            key={ref.id}
                            className="text-xs p-3 rounded-xl border border-border/50 flex justify-between items-center bg-accent/5"
                          >
                            <div className="flex items-center gap-2">
                              <Avatar className="h-6 w-6">
                                <AvatarFallback className="text-[10px]">
                                  {ref.profiles?.username?.[0]}
                                </AvatarFallback>
                              </Avatar>
                              <div className="flex flex-col gap-0.5">
                                <span className="font-bold">@{ref.profiles?.username}</span>
                                <span className="text-[10px] opacity-60">
                                  {ref.profiles?.email}
                                </span>
                              </div>
                            </div>
                            <Badge
                              variant={ref.status === "completed" ? "secondary" : "outline"}
                              className="text-[10px] capitalize"
                            >
                              {ref.status}
                            </Badge>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="text-center py-8 text-xs text-muted-foreground">
                        No referrals yet
                      </div>
                    )}
                  </CardContent>
                </Card>
              </div>

              {/* Redemptions */}
              {userDetails?.redemptions && userDetails.redemptions.length > 0 && (
                <div className="space-y-4">
                  <h3 className="text-sm font-black uppercase flex items-center gap-2">
                    <Gift className="h-4 w-4" /> Rewards History
                  </h3>
                  <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
                    {userDetails.redemptions.map((red: any) => (
                      <div
                        key={red.id}
                        className="p-3 rounded-xl border border-border/50 bg-accent/5 text-xs"
                      >
                        <div className="font-bold mb-1">{red.rewards?.title}</div>
                        <div className="flex justify-between items-center opacity-70">
                          <span>{red.rewards?.cost_points} pts</span>
                          <span className="capitalize">{red.status}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
