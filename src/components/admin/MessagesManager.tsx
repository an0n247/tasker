import { useState, useEffect, useMemo } from "react";
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
  Search,
  CheckCircle2,
  AlertCircle,
  Eye,
  Clock,
  HelpCircle,
  RefreshCw,
  LifeBuoy,
  Inbox,
  CheckCircle,
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

type TicketFilter = "all" | "pending" | "answered" | "broadcasts";

export function MessagesManager() {
  const queryClient = useQueryClient();
  const [isComposeOpen, setIsComposeOpen] = useState(false);
  const [activeSheetThreadId, setActiveSheetThreadId] = useState<string | null>(null);

  // Form state for new announcement or direct user message
  const [isBroadcast, setIsBroadcast] = useState(false);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [userSearchQuery, setUserSearchQuery] = useState("");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [allowReplies, setAllowReplies] = useState(true);

  // Filter state - primary inbox dedicated to support tickets
  const [filterType, setFilterType] = useState<TicketFilter>("all");
  const [searchFilter, setSearchFilter] = useState("");

  // Staff reply in drawer
  const [staffReplyText, setStaffReplyText] = useState("");

  // Fetch only incoming support tickets & inquiries (general broadcasts excluded from support inbox)
  const {
    data: allThreads = [],
    isLoading,
    isFetching,
    refetch,
  } = useQuery({
    queryKey: ["admin-support-tickets"],
    queryFn: async () => {
      // 1. Fetch root threads (parent_id IS NULL)
      const { data: rawMessages, error } = await supabase
        .from("messages" as any)
        .select("*")
        .is("parent_id", null)
        .order("updated_at", { ascending: false });

      if (error) {
        console.error("Error fetching support messages:", error);
        return [];
      }

      const msgs = (rawMessages || []) as any[];
      if (msgs.length === 0) return [];

      // Collect user IDs for sender and recipient
      const userIds = Array.from(
        new Set(msgs.flatMap((m: any) => [m.sender_id, m.recipient_id]).filter(Boolean))
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url")
        .in("id", userIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      // 2. Fetch replies to determine response status (pending vs answered)
      const { data: allReplies } = await supabase
        .from("messages" as any)
        .select("id, parent_id, sender_id, created_at")
        .not("parent_id", "is", null)
        .order("created_at", { ascending: true });

      const threadRepliesMap = new Map<string, any[]>();
      (allReplies || []).forEach((r: any) => {
        const list = threadRepliesMap.get(r.parent_id) || [];
        list.push(r);
        threadRepliesMap.set(r.parent_id, list);
      });

      return msgs.map((t: any) => {
        const replies = threadRepliesMap.get(t.id) || [];
        const replyCount = replies.length;
        const lastReply = replies[replies.length - 1];

        // Is this a user-submitted support ticket?
        // User support tickets are not broadcasts, and recipient_id is null or sent to support
        const isSupportTicket = !t.is_broadcast && (!t.recipient_id || t.recipient_id === null);
        const isBroadcastMessage = Boolean(t.is_broadcast);

        // A ticket is answered if staff has replied and the last reply was from staff (not user)
        const hasStaffReply = replies.some((r: any) => r.sender_id !== t.sender_id);
        const needsReply = !hasStaffReply || (lastReply && lastReply.sender_id === t.sender_id);

        return {
          ...t,
          sender: profileMap.get(t.sender_id) || {
            id: t.sender_id,
            username: "Member",
            full_name: "Member",
            email: "",
          },
          recipient: t.recipient_id
            ? profileMap.get(t.recipient_id) || { id: t.recipient_id, username: "User", email: "" }
            : null,
          replyCount,
          isSupportTicket,
          isBroadcastMessage,
          needsReply,
          isAnswered: hasStaffReply && !needsReply,
        };
      });
    },
  });

  // Filter threads: Support inbox by default only shows incoming user tickets
  const supportTickets = useMemo(
    () => allThreads.filter((t: any) => !t.isBroadcastMessage),
    [allThreads]
  );
  const broadcastMessages = useMemo(
    () => allThreads.filter((t: any) => t.isBroadcastMessage),
    [allThreads]
  );

  const pendingCount = useMemo(
    () => supportTickets.filter((t: any) => t.needsReply).length,
    [supportTickets]
  );
  const answeredCount = useMemo(
    () => supportTickets.filter((t: any) => !t.needsReply).length,
    [supportTickets]
  );
  const broadcastCount = useMemo(() => broadcastMessages.length, [broadcastMessages]);

  const filteredThreads = useMemo(() => {
    let list = allThreads;

    if (filterType === "all") {
      // In the main support inbox, only display support tickets sent by users
      list = supportTickets;
    } else if (filterType === "pending") {
      list = supportTickets.filter((t: any) => t.needsReply);
    } else if (filterType === "answered") {
      list = supportTickets.filter((t: any) => !t.needsReply);
    } else if (filterType === "broadcasts") {
      list = broadcastMessages;
    }

    if (searchFilter.trim()) {
      const q = searchFilter.toLowerCase();
      list = list.filter((t: any) => {
        const matchSubject = t.subject?.toLowerCase().includes(q);
        const matchBody = t.body?.toLowerCase().includes(q);
        const matchUser =
          t.sender?.username?.toLowerCase().includes(q) ||
          t.sender?.email?.toLowerCase().includes(q) ||
          t.sender?.full_name?.toLowerCase().includes(q);
        return matchSubject || matchBody || matchUser;
      });
    }

    return list;
  }, [allThreads, supportTickets, broadcastMessages, filterType, searchFilter]);

  // Real-time synchronization for admin panel
  useEffect(() => {
    const channel = supabase
      .channel("admin-support-realtime")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "messages",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["admin-support-tickets"] });
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

  // User search query for compose
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

  // Send Message / Broadcast Mutation (with Direct Table Fallback)
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

      // Create notification
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
      toast.success(isBroadcast ? "Broadcast announcement sent!" : "Direct message sent to user!");
      setIsComposeOpen(false);
      resetComposeForm();
      queryClient.invalidateQueries({ queryKey: ["admin-support-tickets"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to send message.");
    },
  });

  // Staff Reply Mutation (with Direct Table Fallback)
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
            title: "Support Ticket Update ✉️",
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
      queryClient.invalidateQueries({ queryKey: ["admin-support-tickets"] });
      toast.success("Support reply sent to user!");
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

  return (
    <div className="space-y-6">
      {/* Top Action Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-3xl bg-ink-2/60 border border-hairline backdrop-blur-xl shadow-lg">
        <div>
          <h2 className="text-lg font-black text-ink-fg flex items-center gap-2">
            <LifeBuoy className="size-5 text-gold" />
            Support Inbox & Ticket Desk
          </h2>
          <p className="text-xs text-ink-muted">
            Dedicated inbox configured strictly for receiving and responding to member support
            tickets and inquiries.
          </p>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <Button
            variant="outline"
            size="sm"
            onClick={() => refetch()}
            disabled={isFetching}
            className="h-11 px-3.5 rounded-2xl border-hairline bg-ink-2/80 text-ink-muted hover:text-gold text-xs font-bold gap-1.5 cursor-pointer"
            title="Refresh tickets"
          >
            <RefreshCw className={cn("size-3.5", isFetching && "animate-spin text-gold")} />
            <span className="hidden sm:inline">Refresh</span>
          </Button>

          <Button
            onClick={() => {
              resetComposeForm();
              setIsComposeOpen(true);
            }}
            variant="outline"
            className="h-11 px-4 rounded-2xl font-bold text-xs border-hairline bg-ink-2/80 hover:bg-gold/10 hover:text-gold gap-2 shrink-0 cursor-pointer"
          >
            <Megaphone className="size-4 text-amber-400" />
            <span>Broadcast / Notice</span>
          </Button>
        </div>
      </div>

      {/* Ticket Metrics Row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <div className="flex items-center justify-between">
            <p className="text-xs text-ink-muted font-medium">Total Support Tickets</p>
            <HelpCircle className="size-4 text-blue-400 opacity-60" />
          </div>
          <p className="text-2xl font-black text-ink-fg font-mono">{supportTickets.length}</p>
        </div>

        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 space-y-1">
          <div className="flex items-center justify-between">
            <p className="text-xs text-amber-400 font-bold">Needs Staff Reply</p>
            <AlertCircle className="size-4 text-amber-400" />
          </div>
          <p className="text-2xl font-black text-amber-400 font-mono">{pendingCount}</p>
        </div>

        <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 space-y-1">
          <div className="flex items-center justify-between">
            <p className="text-xs text-emerald-400 font-bold">Answered Tickets</p>
            <CheckCircle2 className="size-4 text-emerald-400" />
          </div>
          <p className="text-2xl font-black text-emerald-400 font-mono">{answeredCount}</p>
        </div>

        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <div className="flex items-center justify-between">
            <p className="text-xs text-ink-muted font-medium">Broadcasts Sent</p>
            <Megaphone className="size-4 text-gold opacity-60" />
          </div>
          <p className="text-2xl font-black text-gold font-mono">{broadcastCount}</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 p-1 bg-ink-2/80 rounded-2xl border border-hairline w-full sm:w-auto overflow-x-auto scrollbar-none">
          <button
            type="button"
            onClick={() => setFilterType("all")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
              filterType === "all" ? "bg-gold text-ink shadow-sm font-black" : "text-ink-muted hover:text-ink-fg"
            )}
          >
            <span>All Tickets</span>
            <span className="px-1.5 py-0.2 rounded-md text-[10px] font-mono bg-ink/10">
              {supportTickets.length}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setFilterType("pending")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
              filterType === "pending"
                ? "bg-amber-500 text-ink shadow-sm font-black"
                : "text-amber-400 hover:text-amber-300 hover:bg-amber-500/10"
            )}
          >
            <AlertCircle className="size-3.5" />
            <span>Needs Reply</span>
            {pendingCount > 0 && (
              <span className="px-1.5 py-0.2 rounded-md text-[10px] font-mono bg-amber-900/40 text-amber-200">
                {pendingCount}
              </span>
            )}
          </button>

          <button
            type="button"
            onClick={() => setFilterType("answered")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
              filterType === "answered"
                ? "bg-emerald-500 text-ink shadow-sm font-black"
                : "text-emerald-400 hover:text-emerald-300 hover:bg-emerald-500/10"
            )}
          >
            <CheckCircle2 className="size-3.5" />
            <span>Answered</span>
            <span className="px-1.5 py-0.2 rounded-md text-[10px] font-mono bg-ink/10">
              {answeredCount}
            </span>
          </button>

          <button
            type="button"
            onClick={() => setFilterType("broadcasts")}
            className={cn(
              "px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
              filterType === "broadcasts"
                ? "bg-gold text-ink shadow-sm font-black"
                : "text-ink-muted hover:text-ink-fg"
            )}
          >
            <Megaphone className="size-3.5" />
            <span>Broadcasts</span>
            <span className="px-1.5 py-0.2 rounded-md text-[10px] font-mono bg-ink/10">
              {broadcastCount}
            </span>
          </button>
        </div>

        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-ink-muted" />
          <Input
            placeholder="Search tickets by user or text..."
            value={searchFilter}
            onChange={(e) => setSearchFilter(e.target.value)}
            className="pl-9 h-10 bg-ink-2/60 border-hairline rounded-xl text-xs"
          />
        </div>
      </div>

      {/* Support Tickets List */}
      <div className="rounded-3xl border border-hairline bg-ink-2/30 overflow-hidden shadow-xl">
        {isLoading ? (
          <div className="py-16 text-center text-xs text-ink-muted space-y-2">
            <div className="size-6 border-2 border-gold border-t-transparent rounded-full animate-spin mx-auto" />
            <p>Loading support inbox...</p>
          </div>
        ) : filteredThreads.length === 0 ? (
          <div className="py-16 text-center text-ink-muted space-y-3">
            <div className="size-12 rounded-2xl bg-ink-2 border border-hairline flex items-center justify-center mx-auto">
              <Inbox className="size-6 text-ink-muted" />
            </div>
            <p className="text-sm font-bold text-ink-fg">
              {filterType === "pending"
                ? "All caught up! No pending tickets."
                : "No support tickets found"}
            </p>
            <p className="text-xs text-ink-muted max-w-sm mx-auto">
              User inquiries and support requests sent from the member portal will appear here
              automatically.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-hairline/60">
            {filteredThreads.map((thread: any) => {
              const senderProfile = thread.sender;

              return (
                <div
                  key={thread.id}
                  className={cn(
                    "p-4 sm:p-5 transition-colors flex flex-col sm:flex-row sm:items-center justify-between gap-4",
                    thread.needsReply && !thread.isBroadcastMessage
                      ? "bg-amber-500/[0.03] hover:bg-amber-500/[0.07]"
                      : "hover:bg-ink-2/60"
                  )}
                >
                  <div className="flex items-start gap-3.5 min-w-0">
                    <Avatar className="size-10 rounded-xl border border-hairline shrink-0 bg-ink-2">
                      <AvatarImage src={senderProfile?.avatar_url || ""} />
                      <AvatarFallback className="bg-gold/15 text-gold font-bold text-xs">
                        {thread.isBroadcastMessage ? (
                          <Megaphone className="size-4" />
                        ) : (
                          <User className="size-4" />
                        )}
                      </AvatarFallback>
                    </Avatar>

                    <div className="min-w-0 space-y-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <h4 className="text-xs sm:text-sm font-black text-ink-fg truncate">
                          {thread.subject || "Support Inquiry"}
                        </h4>

                        {thread.isBroadcastMessage ? (
                          <Badge
                            variant="outline"
                            className="text-[9px] bg-gold/10 border-gold/30 text-gold font-bold gap-1"
                          >
                            <Megaphone className="size-3" />
                            Global Notice
                          </Badge>
                        ) : thread.needsReply ? (
                          <Badge className="text-[9px] bg-amber-500/20 border border-amber-500/40 text-amber-400 font-bold gap-1">
                            <AlertCircle className="size-3" />
                            Needs Reply
                          </Badge>
                        ) : (
                          <Badge className="text-[9px] bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 font-bold gap-1">
                            <CheckCircle className="size-3" />
                            Answered
                          </Badge>
                        )}

                        {!thread.isBroadcastMessage && (
                          <span className="text-[11px] text-ink-muted font-mono font-medium">
                            from @{senderProfile?.username || "Member"}
                            {senderProfile?.email ? ` (${senderProfile.email})` : ""}
                          </span>
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
                        Submitted {format(new Date(thread.created_at), "MMM d, yyyy h:mm a")} • Updated{" "}
                        {formatDistanceToNow(new Date(thread.updated_at), { addSuffix: true })}
                      </p>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setActiveSheetThreadId(thread.id)}
                      className={cn(
                        "h-9 px-4 rounded-xl font-bold text-xs border-hairline gap-1.5 transition-all cursor-pointer",
                        thread.needsReply && !thread.isBroadcastMessage
                          ? "bg-amber-500/15 text-amber-400 border-amber-500/40 hover:bg-amber-500/25"
                          : "bg-ink-2/80 hover:bg-gold/15 hover:text-gold hover:border-gold/40"
                      )}
                    >
                      <Eye className="size-3.5" />
                      <span>{thread.needsReply ? "Reply to Ticket" : "View Ticket"}</span>
                    </Button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Broadcast Announcement / Direct Notice Modal */}
      <Dialog open={isComposeOpen} onOpenChange={setIsComposeOpen}>
        <DialogContent className="max-w-xl bg-ink-2 border-hairline text-ink-fg rounded-3xl p-6 shadow-2xl">
          <DialogHeader className="space-y-1">
            <DialogTitle className="text-lg font-black text-ink-fg flex items-center gap-2">
              <Megaphone className="size-5 text-gold" />
              Broadcast Announcement / Direct Notice
            </DialogTitle>
            <DialogDescription className="text-xs text-ink-muted">
              Publish platform-wide announcements or send direct administrative notices to specific
              members.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-2">
            {/* Delivery Type Selector */}
            <div className="p-3 rounded-2xl bg-ink/70 border border-hairline flex items-center justify-between gap-4">
              <div className="space-y-0.5">
                <Label className="text-xs font-bold text-ink-fg">Broadcast to All Users</Label>
                <p className="text-[11px] text-ink-muted">
                  Send this announcement globally to all registered platform members.
                </p>
              </div>
              <Switch checked={isBroadcast} onCheckedChange={setIsBroadcast} />
            </div>

            {/* Recipient Selection (if not broadcast) */}
            {!isBroadcast && (
              <div className="space-y-2">
                <Label className="text-xs font-bold text-ink-fg">Select Member</Label>
                {selectedUser ? (
                  <div className="p-3 rounded-2xl bg-gold/10 border border-gold/30 flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2.5">
                      <Avatar className="size-8 rounded-lg bg-gold/20">
                        <AvatarImage src={selectedUser.avatar_url || ""} />
                        <AvatarFallback className="text-xs font-bold text-gold">
                          {selectedUser.username?.slice(0, 2).toUpperCase() || "U"}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <p className="text-xs font-bold text-ink-fg">
                          {selectedUser.full_name || selectedUser.username}
                        </p>
                        <p className="text-[10px] text-ink-muted font-mono">
                          @{selectedUser.username} {selectedUser.email ? `• ${selectedUser.email}` : ""}
                        </p>
                      </div>
                    </div>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setSelectedUser(null)}
                      className="text-xs h-7 px-2 text-rose-400 hover:text-rose-300 hover:bg-rose-500/10 cursor-pointer"
                    >
                      Change
                    </Button>
                  </div>
                ) : (
                  <div className="space-y-2">
                    <div className="relative">
                      <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-3.5 text-ink-muted" />
                      <Input
                        placeholder="Search by username, name, or email..."
                        value={userSearchQuery}
                        onChange={(e) => setUserSearchQuery(e.target.value)}
                        className="pl-9 h-9 text-xs bg-ink/70 border-hairline rounded-xl"
                      />
                    </div>
                    <div className="max-h-36 overflow-y-auto rounded-xl border border-hairline bg-ink/50 divide-y divide-hairline">
                      {isSearchingUsers ? (
                        <p className="p-3 text-center text-xs text-ink-muted">Searching members...</p>
                      ) : searchedUsers.length === 0 ? (
                        <p className="p-3 text-center text-xs text-ink-muted">No members found</p>
                      ) : (
                        searchedUsers.map((u: any) => (
                          <button
                            key={u.id}
                            type="button"
                            onClick={() => setSelectedUser(u)}
                            className="w-full p-2.5 flex items-center justify-between hover:bg-gold/10 text-left transition-colors cursor-pointer"
                          >
                            <div className="flex items-center gap-2">
                              <Avatar className="size-6 rounded-md">
                                <AvatarImage src={u.avatar_url || ""} />
                                <AvatarFallback className="text-[10px] bg-gold/15 text-gold font-bold">
                                  {u.username?.slice(0, 2).toUpperCase() || "U"}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p className="text-xs font-bold text-ink-fg">
                                  {u.full_name || u.username}
                                </p>
                                <p className="text-[10px] text-ink-muted font-mono">@{u.username}</p>
                              </div>
                            </div>
                            <span className="text-[10px] font-bold text-gold">Select</span>
                          </button>
                        ))
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* Subject */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-ink-fg">Subject Line</Label>
              <Input
                placeholder={isBroadcast ? "Platform Announcement" : "Administrative Notice"}
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                className="h-10 text-xs bg-ink/70 border-hairline rounded-xl"
              />
            </div>

            {/* Body */}
            <div className="space-y-1.5">
              <Label className="text-xs font-bold text-ink-fg">Message Content</Label>
              <Textarea
                placeholder="Write your announcement or notice here..."
                value={body}
                onChange={(e) => setBody(e.target.value)}
                rows={4}
                className="text-xs bg-ink/70 border-hairline rounded-xl resize-none"
              />
            </div>

            {/* Allow Replies Switch */}
            <div className="p-3 rounded-2xl bg-ink/70 border border-hairline flex items-center justify-between gap-4">
              <div className="space-y-0.5">
                <Label className="text-xs font-bold text-ink-fg">Allow User Replies</Label>
                <p className="text-[11px] text-ink-muted">
                  Permit the member to send replies back to this notification.
                </p>
              </div>
              <Switch checked={allowReplies} onCheckedChange={setAllowReplies} />
            </div>
          </div>

          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              onClick={() => setIsComposeOpen(false)}
              className="h-10 text-xs font-bold border-hairline bg-transparent hover:bg-ink-3 rounded-xl cursor-pointer"
            >
              Cancel
            </Button>
            <Button
              onClick={() => sendMessageMutation.mutate()}
              disabled={sendMessageMutation.isPending || !body.trim() || (!isBroadcast && !selectedUser)}
              className="h-10 text-xs font-bold bg-gold text-ink hover:bg-gold-soft border-none rounded-xl gap-2 cursor-pointer shadow-md shadow-gold/20"
            >
              <Send className="size-3.5" />
              <span>{sendMessageMutation.isPending ? "Sending..." : "Send Announcement"}</span>
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Ticket Details & Staff Reply Drawer */}
      <Sheet
        open={!!activeSheetThreadId}
        onOpenChange={(open) => {
          if (!open) {
            setActiveSheetThreadId(null);
            setStaffReplyText("");
          }
        }}
      >
        <SheetContent className="w-full sm:max-w-2xl bg-ink-2 border-hairline text-ink-fg p-0 flex flex-col shadow-2xl">
          <SheetHeader className="p-6 border-b border-hairline space-y-1">
            <div className="flex items-center gap-2">
              <Badge className="bg-blue-500/15 text-blue-400 border-blue-500/30 text-[10px] font-bold">
                Support Ticket
              </Badge>
              {threadDetail?.root?.needsReply ? (
                <Badge className="bg-amber-500/20 text-amber-400 border-amber-500/40 text-[10px] font-bold">
                  Awaiting Staff Response
                </Badge>
              ) : (
                <Badge className="bg-emerald-500/15 text-emerald-400 border-emerald-500/30 text-[10px] font-bold">
                  Answered
                </Badge>
              )}
            </div>

            <SheetTitle className="text-lg font-black text-ink-fg">
              {threadDetail?.root?.subject || "Support Inquiry"}
            </SheetTitle>
            <SheetDescription className="text-xs text-ink-muted">
              Ticket opened by @{threadDetail?.root?.sender?.username || "Member"}
              {threadDetail?.root?.sender?.email ? ` (${threadDetail?.root?.sender?.email})` : ""}
            </SheetDescription>
          </SheetHeader>

          {/* Ticket Messages History */}
          <ScrollArea className="flex-1 p-6">
            {isLoadingDetail ? (
              <div className="py-12 text-center text-xs text-ink-muted space-y-2">
                <div className="size-5 border-2 border-gold border-t-transparent rounded-full animate-spin mx-auto" />
                <p>Loading ticket discussion...</p>
              </div>
            ) : !threadDetail?.root ? (
              <p className="text-center py-12 text-xs text-ink-muted">Ticket not found.</p>
            ) : (
              <div className="space-y-6">
                {/* Initial Root Ticket Message */}
                <div className="p-5 rounded-3xl bg-ink/70 border border-hairline space-y-3">
                  <div className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-2.5">
                      <Avatar className="size-8 rounded-xl bg-ink-2 border border-hairline">
                        <AvatarImage src={threadDetail.root.sender?.avatar_url || ""} />
                        <AvatarFallback className="text-xs font-bold text-gold">
                          {threadDetail.root.sender?.username?.slice(0, 2).toUpperCase() || "U"}
                        </AvatarFallback>
                      </Avatar>
                      <div>
                        <p className="text-xs font-bold text-ink-fg">
                          {threadDetail.root.sender?.full_name || threadDetail.root.sender?.username}
                        </p>
                        <p className="text-[10px] text-ink-muted font-mono">
                          @{threadDetail.root.sender?.username}
                        </p>
                      </div>
                    </div>

                    <span className="text-[10px] text-ink-muted font-mono">
                      {format(new Date(threadDetail.root.created_at), "MMM d, h:mm a")}
                    </span>
                  </div>

                  <p className="text-xs text-ink-fg/90 whitespace-pre-wrap leading-relaxed">
                    {threadDetail.root.body}
                  </p>
                </div>

                {/* Replies Thread */}
                {threadDetail.replies?.length > 0 && (
                  <div className="space-y-4 pl-4 sm:pl-6 border-l-2 border-hairline">
                    {threadDetail.replies.map((reply: any) => {
                      const isStaff = reply.sender_id !== threadDetail.root.sender_id;

                      return (
                        <div
                          key={reply.id}
                          className={cn(
                            "p-4 rounded-2xl border space-y-2 text-xs",
                            isStaff
                              ? "bg-gold/10 border-gold/25 text-ink-fg ml-2"
                              : "bg-ink/50 border-hairline text-ink-fg/90 mr-2"
                          )}
                        >
                          <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-2">
                              <span className="font-bold text-[11px] text-ink-fg flex items-center gap-1.5">
                                {isStaff ? (
                                  <>
                                    <Shield className="size-3 text-gold" />
                                    <span className="text-gold font-black">Support Staff</span>
                                  </>
                                ) : (
                                  <>
                                    <User className="size-3 text-ink-muted" />
                                    <span>@{reply.sender?.username || "Member"}</span>
                                  </>
                                )}
                              </span>
                            </div>
                            <span className="text-[10px] text-ink-muted font-mono">
                              {format(new Date(reply.created_at), "MMM d, h:mm a")}
                            </span>
                          </div>

                          <p className="whitespace-pre-wrap leading-relaxed">{reply.body}</p>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </ScrollArea>

          {/* Sticky Staff Reply Section */}
          <div className="p-4 sm:p-6 border-t border-hairline bg-ink-2/95 space-y-3">
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label className="text-xs font-bold text-ink-fg flex items-center gap-1.5">
                  <MessageSquare className="size-3.5 text-gold" />
                  Staff Response to Member
                </Label>
                <span className="text-[10px] text-ink-muted font-mono">
                  User will be notified immediately
                </span>
              </div>
              <Textarea
                placeholder="Type your official support reply here..."
                value={staffReplyText}
                onChange={(e) => setStaffReplyText(e.target.value)}
                rows={3}
                className="text-xs bg-ink/80 border-hairline rounded-2xl resize-none"
              />
            </div>

            <div className="flex items-center justify-end gap-2">
              <Button
                onClick={() => staffReplyMutation.mutate(staffReplyText)}
                disabled={staffReplyMutation.isPending || !staffReplyText.trim()}
                className="h-10 px-5 text-xs font-bold bg-gold text-ink hover:bg-gold-soft border-none rounded-xl gap-2 cursor-pointer shadow-md shadow-gold/20"
              >
                <Send className="size-3.5" />
                <span>{staffReplyMutation.isPending ? "Sending..." : "Send Staff Reply"}</span>
              </Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
