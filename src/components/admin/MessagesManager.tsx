import { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  Mail,
  Send,
  Plus,
  Megaphone,
  User,
  Shield,
  MessageSquare,
  Lock,
  Search,
  CheckCircle2,
  AlertCircle,
  Users,
  Eye,
  Radio,
  CornerDownRight,
  Clock,
  HelpCircle,
  RefreshCw,
} from "lucide-react";
import { formatDistanceToNow, format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

export function MessagesManager() {
  const queryClient = useQueryClient();
  const [isComposeOpen, setIsComposeOpen] = useState(false);
  const [activeSheetThreadId, setActiveSheetThreadId] = useState<string | null>(null);

  // Form state
  const [isBroadcast, setIsBroadcast] = useState(false);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [userSearchQuery, setUserSearchQuery] = useState("");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [allowReplies, setAllowReplies] = useState(true);

  // Filter state
  const [filterType, setFilterType] = useState<"all" | "direct" | "broadcast" | "support">("all");
  const [searchFilter, setSearchFilter] = useState("");

  // Staff reply in drawer
  const [staffReplyText, setStaffReplyText] = useState("");

  // Fetch all threads
  const {
    data: threads = [],
    isLoading,
    isFetching,
    refetch,
  } = useQuery({
    queryKey: ["admin-messages-threads"],
    queryFn: async () => {
      const { data: rawMessages, error } = await supabase
        .from("messages" as any)
        .select("*")
        .is("parent_id", null)
        .order("updated_at", { ascending: false });

      if (error) {
        console.error("Error fetching admin messages:", error);
        return [];
      }

      const msgs = (rawMessages || []) as any[];
      if (msgs.length === 0) return [];

      // Collect user IDs
      const userIds = Array.from(
        new Set(
          msgs.flatMap((m: any) => [m.sender_id, m.recipient_id]).filter(Boolean)
        )
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url")
        .in("id", userIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      // Also get reply counts
      const { data: allReplies } = await supabase
        .from("messages" as any)
        .select("id, parent_id")
        .not("parent_id", "is", null);

      const replyCountMap = new Map<string, number>();
      (allReplies || []).forEach((r: any) => {
        replyCountMap.set(r.parent_id, (replyCountMap.get(r.parent_id) || 0) + 1);
      });

      return msgs.map((t: any) => ({
        ...t,
        sender: profileMap.get(t.sender_id) || { id: t.sender_id, username: "Member", email: "" },
        recipient: t.recipient_id
          ? profileMap.get(t.recipient_id) || { id: t.recipient_id, username: "User", email: "" }
          : null,
        replyCount: replyCountMap.get(t.id) || 0,
        isUserInquiry: !t.is_broadcast && !t.recipient_id,
      }));
    },
  });

  // Real-time synchronization for admin panel
  useEffect(() => {
    const channel = supabase
      .channel("admin-messages-realtime")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "messages",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["admin-messages-threads"] });
          if (activeSheetThreadId) {
            queryClient.invalidateQueries({
              queryKey: ["admin-thread-detail", activeSheetThreadId],
            });
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeSheetThreadId, queryClient]);

  // User search query for compose - returns recent users immediately
  const { data: searchedUsers = [], isLoading: isSearchingUsers } = useQuery({
    queryKey: ["admin-user-search-msg", userSearchQuery],
    queryFn: async () => {
      let query = supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url");

      if (userSearchQuery && userSearchQuery.trim().length > 0) {
        query = query.or(
          `username.ilike.%${userSearchQuery.trim()}%,full_name.ilike.%${userSearchQuery.trim()}%,email.ilike.%${userSearchQuery.trim()}%`
        );
      } else {
        query = query.order("created_at", { ascending: false });
      }

      const { data, error } = await query.limit(10);
      if (error) {
        console.error("Error fetching profiles for message selection:", error);
        return [];
      }
      return data || [];
    },
    enabled: !isBroadcast,
  });

  // Fetch specific thread details for sheet drawer
  const { data: threadDetail, isLoading: isLoadingDetail } = useQuery({
    queryKey: ["admin-thread-detail", activeSheetThreadId],
    queryFn: async () => {
      if (!activeSheetThreadId) return null;

      const [{ data: rootRaw }, { data: repliesRaw }] = await Promise.all([
        supabase
          .from("messages" as any)
          .select("*")
          .eq("id", activeSheetThreadId)
          .maybeSingle(),
        supabase
          .from("messages" as any)
          .select("*")
          .eq("parent_id", activeSheetThreadId)
          .order("created_at", { ascending: true }),
      ]);

      if (!rootRaw) return null;

      const root = rootRaw as any;
      const replies = (repliesRaw || []) as any[];

      const allUserIds = Array.from(
        new Set(
          [
            root.sender_id,
            root.recipient_id,
            ...replies.flatMap((r: any) => [r.sender_id, r.recipient_id]),
          ].filter(Boolean)
        )
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url")
        .in("id", allUserIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      const enrichedRoot = {
        ...root,
        sender: profileMap.get(root.sender_id) || {
          id: root.sender_id,
          username: "Member",
          email: "",
        },
        recipient: root.recipient_id
          ? profileMap.get(root.recipient_id) || {
              id: root.recipient_id,
              username: "User",
              email: "",
            }
          : null,
      };

      const enrichedReplies = replies.map((r: any) => ({
        ...r,
        sender: profileMap.get(r.sender_id) || {
          id: r.sender_id,
          username: "Participant",
          email: "",
        },
        recipient: r.recipient_id
          ? profileMap.get(r.recipient_id) || {
              id: r.recipient_id,
              username: "Recipient",
              email: "",
            }
          : null,
      }));

      return { root: enrichedRoot, replies: enrichedReplies };
    },
    enabled: !!activeSheetThreadId,
  });

  // Send Message Mutation (with bulletproof Direct Table Fallback)
  const sendMessageMutation = useMutation({
    mutationFn: async () => {
      const { data: authData } = await supabase.auth.getUser();
      const currentUser = authData?.user;
      if (!currentUser) throw new Error("Not authenticated. Please log in.");

      if (!isBroadcast && !selectedUser) {
        throw new Error("Please select a recipient for direct message.");
      }
      if (!body.trim()) {
        throw new Error("Message body is required.");
      }

      const trimmedSubject =
        subject.trim() || (isBroadcast ? "Platform Announcement" : "Administrative Notice");
      const trimmedBody = body.trim();
      const targetRecipientId = isBroadcast ? null : selectedUser.id;

      // 1. Try RPC first
      try {
        const { data: rpcData, error: rpcError } = await supabase.rpc("send_admin_message", {
          p_recipient_id: targetRecipientId,
          p_subject: trimmedSubject,
          p_body: trimmedBody,
          p_allow_replies: allowReplies,
          p_is_broadcast: isBroadcast,
        });

        if (!rpcError && (rpcData as any)?.success) {
          return rpcData;
        }
      } catch (e) {
        console.warn("RPC send_admin_message error, attempting direct insert fallback:", e);
      }

      // 2. Direct table insert fallback
      const { data: inserted, error: insertError } = await supabase
        .from("messages" as any)
        .insert({
          sender_id: currentUser.id,
          recipient_id: targetRecipientId,
          subject: trimmedSubject,
          body: trimmedBody,
          allow_replies: allowReplies,
          is_broadcast: isBroadcast,
          is_read: false,
        })
        .select()
        .single();

      if (insertError) {
        throw new Error(insertError.message || "Failed to send message");
      }

      // Also create notification if possible
      try {
        if (isBroadcast) {
          const { data: profiles } = await supabase.from("profiles").select("id");
          if (profiles && profiles.length > 0) {
            await supabase.from("notifications").insert(
              profiles.map((p) => ({
                user_id: p.id,
                title: trimmedSubject,
                message: trimmedBody.slice(0, 120),
                type: "system",
                metadata: { message_id: inserted.id, is_broadcast: true },
              }))
            );
          }
        } else if (targetRecipientId) {
          await supabase.from("notifications").insert({
            user_id: targetRecipientId,
            title: trimmedSubject,
            message: trimmedBody.slice(0, 120),
            type: "message",
            metadata: { message_id: inserted.id },
          });
        }
      } catch (nErr) {
        console.warn("Notification insert error:", nErr);
      }

      return { success: true, message_id: inserted.id };
    },
    onSuccess: () => {
      toast.success(isBroadcast ? "Broadcast announcement sent!" : "Message sent to user!");
      setIsComposeOpen(false);
      resetComposeForm();
      queryClient.invalidateQueries({ queryKey: ["admin-messages-threads"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to send message.");
    },
  });

  // Staff Reply Mutation (with bulletproof Direct Table Fallback)
  const staffReplyMutation = useMutation({
    mutationFn: async (text: string) => {
      const { data: authData } = await supabase.auth.getUser();
      const currentUser = authData?.user;
      if (!currentUser) throw new Error("Not authenticated");
      if (!activeSheetThreadId) throw new Error("No active thread");
      const trimmed = text.trim();
      if (!trimmed) throw new Error("Reply cannot be empty");

      // 1. Try RPC first
      try {
        const { data: rpcData, error: rpcError } = await supabase.rpc("send_message_reply", {
          p_parent_id: activeSheetThreadId,
          p_body: trimmed,
        });

        if (!rpcError && (rpcData as any)?.success) {
          return rpcData;
        }
      } catch (e) {
        console.warn("RPC staff reply error, attempting direct insert fallback:", e);
      }

      // 2. Direct insert fallback
      const root = threadDetail?.root;
      const targetRecipient =
        root?.sender_id !== currentUser.id ? root?.sender_id : root?.recipient_id;

      const { data: inserted, error: insertError } = await supabase
        .from("messages" as any)
        .insert({
          parent_id: activeSheetThreadId,
          sender_id: currentUser.id,
          recipient_id: targetRecipient || null,
          body: trimmed,
          allow_replies: true,
          is_broadcast: false,
          is_read: false,
        })
        .select()
        .single();

      if (insertError) {
        throw new Error(insertError.message || "Failed to post reply");
      }

      await supabase
        .from("messages" as any)
        .update({ updated_at: new Date().toISOString() })
        .eq("id", activeSheetThreadId);

      if (targetRecipient) {
        try {
          await supabase.from("notifications").insert({
            user_id: targetRecipient,
            title: "New Reply from Administration ✉️",
            message: trimmed.slice(0, 120),
            type: "message",
            metadata: { message_id: activeSheetThreadId, reply_id: inserted.id },
          });
        } catch (nErr) {
          console.warn("Notification insert error:", nErr);
        }
      }

      return { success: true, reply_id: inserted.id };
    },
    onSuccess: () => {
      setStaffReplyText("");
      queryClient.invalidateQueries({
        queryKey: ["admin-thread-detail", activeSheetThreadId],
      });
      queryClient.invalidateQueries({ queryKey: ["admin-messages-threads"] });
      toast.success("Staff reply posted successfully!");
    },
    onError: (err: any) => {
      toast.error(err.message || "Could not post reply.");
    },
  });

  const resetComposeForm = () => {
    setIsBroadcast(false);
    setSelectedUser(null);
    setUserSearchQuery("");
    setSubject("");
    setBody("");
    setAllowReplies(true);
  };

  const filteredThreads = threads.filter((t: any) => {
    if (filterType === "direct" && (t.is_broadcast || t.isUserInquiry)) return false;
    if (filterType === "broadcast" && !t.is_broadcast) return false;
    if (filterType === "support" && !t.isUserInquiry) return false;

    if (searchFilter.trim()) {
      const q = searchFilter.toLowerCase();
      const matchSubject = t.subject?.toLowerCase().includes(q);
      const matchBody = t.body?.toLowerCase().includes(q);
      const matchUser =
        t.recipient?.username?.toLowerCase().includes(q) ||
        t.recipient?.email?.toLowerCase().includes(q) ||
        t.recipient?.full_name?.toLowerCase().includes(q) ||
        t.sender?.username?.toLowerCase().includes(q) ||
        t.sender?.email?.toLowerCase().includes(q) ||
        t.sender?.full_name?.toLowerCase().includes(q);
      return matchSubject || matchBody || matchUser;
    }
    return true;
  });

  const directCount = threads.filter((t: any) => !t.is_broadcast && !t.isUserInquiry).length;
  const broadcastCount = threads.filter((t: any) => t.is_broadcast).length;
  const supportCount = threads.filter((t: any) => t.isUserInquiry).length;

  return (
    <div className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-3xl bg-ink-2/60 border border-hairline backdrop-blur-xl shadow-lg">
        <div>
          <h2 className="text-lg font-black text-ink-fg flex items-center gap-2">
            <Mail className="size-5 text-gold" />
            Communications & Messages Console
          </h2>
          <p className="text-xs text-ink-muted">
            Send direct communications to users, broadcast global announcements, and respond to
            member support inquiries in real time.
          </p>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isFetching}
            className="h-11 px-3.5 rounded-2xl border-hairline bg-ink-2/80 text-ink-muted hover:text-gold text-xs font-bold gap-1.5 cursor-pointer"
            title="Refresh threads"
          >
            <RefreshCw className={cn("size-3.5", isFetching && "animate-spin text-gold")} />
            <span className="hidden sm:inline">Refresh</span>
          </Button>

          <Button
            onClick={() => {
              resetComposeForm();
              setIsComposeOpen(true);
            }}
            className="h-11 px-5 rounded-2xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none shadow-md shadow-gold/20 gap-2 shrink-0 cursor-pointer"
          >
            <Plus className="size-4" />
            <span>New Message / Announcement</span>
          </Button>
        </div>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Total Threads</p>
          <p className="text-2xl font-black text-ink-fg font-mono">{threads.length}</p>
        </div>
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Direct Messages</p>
          <p className="text-2xl font-black text-gold font-mono">{directCount}</p>
        </div>
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Broadcasts</p>
          <p className="text-2xl font-black text-amber-400 font-mono">{broadcastCount}</p>
        </div>
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Support Inquiries</p>
          <p className="text-2xl font-black text-blue-400 font-mono">{supportCount}</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 p-1 bg-ink-2/80 rounded-2xl border border-hairline w-full sm:w-auto overflow-x-auto scrollbar-none">
          <button
            type="button"
            onClick={() => setFilterType("all")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer",
              filterType === "all"
                ? "bg-gold text-ink shadow-sm"
                : "text-ink-muted hover:text-ink-fg"
            )}
          >
            All ({threads.length})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("direct")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer",
              filterType === "direct"
                ? "bg-gold text-ink shadow-sm"
                : "text-ink-muted hover:text-ink-fg"
            )}
          >
            Direct ({directCount})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("broadcast")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer",
              filterType === "broadcast"
                ? "bg-gold text-ink shadow-sm"
                : "text-ink-muted hover:text-ink-fg"
            )}
          >
            Broadcasts ({broadcastCount})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("support")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer",
              filterType === "support"
                ? "bg-gold text-ink shadow-sm"
                : "text-ink-muted hover:text-ink-fg"
            )}
          >
            Inquiries ({supportCount})
          </button>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-ink-muted" />
          <Input
            placeholder="Search by subject, body, user..."
            value={searchFilter}
            onChange={(e) => setSearchFilter(e.target.value)}
            className="pl-9 h-10 bg-ink-2/60 border-hairline rounded-xl text-xs"
          />
        </div>
      </div>

      {/* Conversations List */}
      <div className="rounded-3xl border border-hairline bg-ink-2/30 overflow-hidden shadow-xl">
        {isLoading ? (
          <div className="py-16 text-center text-xs text-ink-muted space-y-2">
            <div className="size-6 border-2 border-gold border-t-transparent rounded-full animate-spin mx-auto" />
            <p>Loading administrative threads...</p>
          </div>
        ) : filteredThreads.length === 0 ? (
          <div className="py-16 text-center text-ink-muted space-y-3">
            <div className="size-12 rounded-2xl bg-ink-2 border border-hairline flex items-center justify-center mx-auto">
              <Mail className="size-6 text-ink-muted" />
            </div>
            <p className="text-sm font-bold text-ink-fg">No communications found</p>
            <p className="text-xs text-ink-muted">Click "New Message" to initiate a conversation.</p>
          </div>
        ) : (
          <div className="divide-y divide-hairline/60">
            {filteredThreads.map((thread: any) => {
              const displayAvatar = thread.is_broadcast
                ? null
                : thread.isUserInquiry
                ? thread.sender?.avatar_url
                : thread.recipient?.avatar_url;

              return (
                <div
                  key={thread.id}
                  className="p-4 sm:p-5 hover:bg-ink-2/60 transition-colors flex flex-col sm:flex-row sm:items-center justify-between gap-4"
                >
                  <div className="flex items-start gap-3.5 min-w-0">
                    <Avatar className="size-10 rounded-xl border border-hairline shrink-0 bg-ink-2">
                      <AvatarImage src={displayAvatar || ""} />
                      <AvatarFallback className="bg-gold/15 text-gold font-bold text-xs">
                        {thread.is_broadcast ? (
                          <Megaphone className="size-4" />
                        ) : thread.isUserInquiry ? (
                          <HelpCircle className="size-4 text-blue-400" />
                        ) : (
                          <User className="size-4" />
                        )}
                      </AvatarFallback>
                    </Avatar>

                    <div className="min-w-0 space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <h4 className="text-xs sm:text-sm font-black text-ink-fg truncate">
                          {thread.subject || "Administrative Notice"}
                        </h4>

                        {thread.is_broadcast ? (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-amber-500/10 border-amber-500/30 text-amber-400 font-bold gap-1"
                          >
                            <Megaphone className="size-3" />
                            Global Broadcast
                          </Badge>
                        ) : thread.isUserInquiry ? (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-blue-500/10 border-blue-500/30 text-blue-400 font-bold gap-1"
                          >
                            <HelpCircle className="size-3" />
                            From: @{thread.sender?.username || "Member"} (Support Ticket)
                          </Badge>
                        ) : (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-gold/10 border-gold/30 text-gold font-bold"
                          >
                            To: @{thread.recipient?.username || thread.recipient?.email || "User"}
                          </Badge>
                        )}

                        {thread.allow_replies ? (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-emerald-500/10 border-emerald-500/30 text-emerald-400 font-bold"
                          >
                            Replies Allowed
                          </Badge>
                        ) : (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-slate-500/10 border-slate-500/30 text-slate-400 font-bold"
                          >
                            Read-Only
                          </Badge>
                        )}

                        {thread.replyCount > 0 && (
                          <Badge
                            variant="secondary"
                            className="text-[9px] bg-ink-3 text-gold font-mono font-bold"
                          >
                            {thread.replyCount} {thread.replyCount === 1 ? "reply" : "replies"}
                          </Badge>
                        )}
                      </div>

                      <p className="text-xs text-ink-muted line-clamp-1">{thread.body}</p>

                      <p className="text-[10px] text-ink-muted font-mono">
                        Sent {format(new Date(thread.created_at), "MMM d, yyyy h:mm a")} • Updated{" "}
                        {formatDistanceToNow(new Date(thread.updated_at), { addSuffix: true })}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setActiveSheetThreadId(thread.id)}
                      className="h-9 px-4 rounded-xl font-bold text-xs border-hairline bg-ink-2/80 hover:bg-gold/15 hover:text-gold hover:border-gold/40 gap-1.5 transition-all cursor-pointer"
                    >
                      <Eye className="size-3.5" />
                      <span>View Conversation</span>
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Compose Message Dialog */}
      <Dialog open={isComposeOpen} onOpenChange={setIsComposeOpen}>
        <DialogContent className="max-w-xl bg-ink-2 border-hairline text-ink-fg rounded-3xl p-6 shadow-2xl">
          <DialogHeader className="space-y-1">
            <DialogTitle className="text-lg font-black text-ink-fg flex items-center gap-2">
              <Mail className="size-5 text-gold" />
              Compose Message / Announcement
            </DialogTitle>
            <DialogDescription className="text-xs text-ink-muted">
              Initiate a communication with an individual member or broadcast to all registered
              accounts.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            {/* Delivery Type Selector */}
            <div className="p-3 rounded-2xl bg-ink/70 border border-hairline flex items-center justify-between gap-4">
              <div className="space-y-0.5">
                <Label className="text-xs font-bold text-ink-fg">Broadcast to All Users</Label>
                <p className="text-[11px] text-ink-muted">
                  Send this message globally to all registered platform users.
                </p>
              </div>
              <Switch checked={isBroadcast} onCheckedChange={setIsBroadcast} />
            </div>

            {/* Recipient Search (Only if NOT broadcast) */}
            {!isBroadcast && (
              <div className="space-y-2">
                <Label className="text-xs font-bold text-ink-fg">Select Recipient User *</Label>
                {selectedUser ? (
                  <div className="flex items-center justify-between p-3 rounded-xl bg-gold/10 border border-gold/30">
                    <div className="flex items-center gap-2.5">
                      <Avatar className="size-8 rounded-lg border border-gold/30">
                        <AvatarImage src={selectedUser.avatar_url || ""} />
                        <AvatarFallback className="text-xs font-bold text-gold bg-ink">
                          {selectedUser.username?.charAt(0)?.toUpperCase() || "U"}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <p className="text-xs font-black text-ink-fg">
                          @{selectedUser.username || "user"}
                        </p>
                        <p className="text-[10px] text-ink-muted">{selectedUser.email}</p>
                      </div>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setSelectedUser(null)}
                      className="text-xs text-rose-400 hover:bg-rose-500/10 h-7 px-2 cursor-pointer"
                    >
                      Change
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-ink-muted" />
                      <Input
                        placeholder="Search user by username or email..."
                        value={userSearchQuery}
                        onChange={(e) => setUserSearchQuery(e.target.value)}
                        className="pl-9 h-10 bg-ink border-hairline rounded-xl text-xs"
                      />
                    </div>

                    {isSearchingUsers ? (
                      <p className="text-[11px] text-ink-muted px-1">Loading users...</p>
                    ) : searchedUsers.length > 0 ? (
                      <div className="max-h-44 overflow-y-auto space-y-1 p-1 bg-ink rounded-xl border border-hairline">
                        {searchedUsers.map((u: any) => (
                          <button
                            key={u.id}
                            type="button"
                            onClick={() => {
                              setSelectedUser(u);
                              setUserSearchQuery("");
                            }}
                            className="w-full text-left p-2 rounded-lg hover:bg-gold/15 flex items-center justify-between gap-2 text-xs transition-colors cursor-pointer"
                          >
                            <div className="flex items-center gap-2">
                              <Avatar className="size-6 rounded-md">
                                <AvatarImage src={u.avatar_url || ""} />
                                <AvatarFallback className="text-[10px] bg-ink-2">
                                  {u.username?.charAt(0)?.toUpperCase()}
                                </AvatarFallback>
                              </Avatar>
                              <span className="font-bold text-ink-fg">@{u.username}</span>
                              <span className="text-[10px] text-ink-muted">{u.email}</span>
                            </div>
                            <span className="text-[10px] text-gold font-bold">Select</span>
                          </button>
                        ))}
                      </div>
                    ) : (
                      <p className="text-[11px] text-ink-muted px-1">No users found.</p>
                    )}
                  </div>
                )}
              </div>
            )}

            {/* Subject */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-ink-fg">Subject / Title</Label>
              <Input
                placeholder="e.g. Important Update Regarding Your Account"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                className="h-10 bg-ink border-hairline rounded-xl text-xs"
              />
            </div>

            {/* Body */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-ink-fg">Message Body *</Label>
              <Textarea
                placeholder="Enter detailed instructions, directives, or announcement..."
                rows={5}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                className="bg-ink border-hairline rounded-xl text-xs resize-none p-3.5"
              />
            </div>

            {/* Allow User Replies Toggle */}
            <div className="p-3.5 rounded-2xl bg-ink/70 border border-hairline flex items-center justify-between gap-4">
              <div className="space-y-0.5">
                <div className="flex items-center gap-2">
                  <Label className="text-xs font-bold text-ink-fg">Allow User Replies</Label>
                  {allowReplies ? (
                    <Badge className="text-[9px] bg-emerald-500/15 text-emerald-400 border-emerald-500/30">
                      Enabled
                    </Badge>
                  ) : (
                    <Badge className="text-[9px] bg-slate-500/15 text-slate-400 border-slate-500/30">
                      Disabled
                    </Badge>
                  )}
                </div>
                <p className="text-[11px] text-ink-muted leading-relaxed">
                  When enabled, recipient can send responses back. When disabled, the message is
                  strictly read-only.
                </p>
              </div>
              <Switch checked={allowReplies} onCheckedChange={setAllowReplies} />
            </div>
          </div>

          <DialogFooter className="pt-2">
            <Button
              variant="ghost"
              onClick={() => setIsComposeOpen(false)}
              className="text-xs rounded-xl"
            >
              Cancel
            </Button>
            <Button
              onClick={() => sendMessageMutation.mutate()}
              disabled={
                sendMessageMutation.isPending || (!isBroadcast && !selectedUser) || !body.trim()
              }
              className="h-10 px-5 rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none gap-2 shadow-md cursor-pointer"
            >
              {sendMessageMutation.isPending ? (
                "Transmitting..."
              ) : (
                <>
                  <span>{isBroadcast ? "Send Broadcast" : "Send Direct Message"}</span>
                  <Send className="size-3.5" />
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Active Conversation Sheet Drawer */}
      <Sheet
        open={!!activeSheetThreadId}
        onOpenChange={(open) => !open && setActiveSheetThreadId(null)}
      >
        <SheetContent className="w-full sm:max-w-xl bg-ink border-hairline p-0 text-ink-fg flex flex-col justify-between">
          <SheetHeader className="p-6 border-b border-hairline">
            <div className="flex items-center gap-2">
              <SheetTitle className="text-base font-black text-ink-fg">
                {threadDetail?.root?.subject || "Administrative Notice"}
              </SheetTitle>
              {threadDetail?.root?.is_broadcast ? (
                <Badge className="text-[9px] bg-amber-500/10 border-amber-500/30 text-amber-400">
                  Broadcast
                </Badge>
              ) : threadDetail?.root?.recipient_id ? (
                <Badge className="text-[9px] bg-gold/10 border-gold/30 text-gold">
                  Direct: @{threadDetail?.root?.recipient?.username || "User"}
                </Badge>
              ) : (
                <Badge className="text-[9px] bg-blue-500/10 border-blue-500/30 text-blue-400">
                  Support Ticket: @{threadDetail?.root?.sender?.username || "Member"}
                </Badge>
              )}
            </div>
            <SheetDescription className="text-xs text-ink-muted">
              Conversation history and administrative responses for this thread.
            </SheetDescription>
          </SheetHeader>

          {/* Conversation Body */}
          <ScrollArea className="flex-1 p-6">
            {isLoadingDetail ? (
              <div className="py-12 text-center text-xs text-ink-muted">Loading thread...</div>
            ) : threadDetail?.root ? (
              <div className="space-y-4">
                {/* Root Message */}
                <div className="p-4 rounded-2xl bg-ink-2 border border-gold/30 space-y-2">
                  <div className="flex items-center justify-between text-xs">
                    <span className="font-bold text-gold flex items-center gap-1.5">
                      <Shield className="size-3.5" />
                      @{threadDetail.root.sender?.username || "Administrator"} (Original Message)
                    </span>
                    <span className="text-[10px] text-ink-muted font-mono">
                      {format(new Date(threadDetail.root.created_at), "MMM d, h:mm a")}
                    </span>
                  </div>
                  <p className="text-xs text-ink-fg whitespace-pre-wrap leading-relaxed">
                    {threadDetail.root.body}
                  </p>
                </div>

                {/* Replies Stream */}
                {threadDetail.replies.map((reply: any) => (
                  <div
                    key={reply.id}
                    className="p-3.5 rounded-2xl bg-ink-2/60 border border-hairline space-y-1.5"
                  >
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-bold text-ink-fg flex items-center gap-1.5">
                        <User className="size-3.5 text-ink-muted" />
                        @{reply.sender?.username || "Member"}
                      </span>
                      <span className="text-[10px] text-ink-muted font-mono">
                        {formatDistanceToNow(new Date(reply.created_at), { addSuffix: true })}
                      </span>
                    </div>
                    <p className="text-xs text-ink-fg whitespace-pre-wrap leading-relaxed">
                      {reply.body}
                    </p>
                  </div>
                ))}
              </div>
            ) : null}
          </ScrollArea>

          {/* Staff Reply Footer */}
          <div className="p-4 sm:p-6 border-t border-hairline bg-ink-2/40 space-y-3">
            <Textarea
              placeholder="Type staff response..."
              value={staffReplyText}
              onChange={(e) => setStaffReplyText(e.target.value)}
              rows={3}
              className="bg-ink border-hairline rounded-xl text-xs resize-none p-3 focus-visible:ring-gold"
            />
            <div className="flex items-center justify-end">
              <Button
                onClick={() => staffReplyMutation.mutate(staffReplyText)}
                disabled={!staffReplyText.trim() || staffReplyMutation.isPending}
                className="h-9 px-5 rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none gap-2 shadow-md cursor-pointer"
              >
                {staffReplyMutation.isPending ? "Posting..." : "Post Staff Reply"}
                <Send className="size-3.5" />
              </Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
