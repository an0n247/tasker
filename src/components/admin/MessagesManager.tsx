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
  const [filterType, setFilterType] = useState<"all" | "direct" | "broadcast">("all");
  const [searchFilter, setSearchFilter] = useState("");

  // Staff reply in drawer
  const [staffReplyText, setStaffReplyText] = useState("");

  // Fetch all threads
  const { data: threads = [], isLoading } = useQuery({
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
        sender: profileMap.get(t.sender_id) || { id: t.sender_id, username: "Admin", email: "" },
        recipient: t.recipient_id ? profileMap.get(t.recipient_id) || { id: t.recipient_id, username: "User", email: "" } : null,
        replyCount: replyCountMap.get(t.id) || 0,
      }));
    },
  });

  // User search query for compose
  const { data: searchedUsers = [], isLoading: isSearchingUsers } = useQuery({
    queryKey: ["admin-user-search-msg", userSearchQuery],
    queryFn: async () => {
      if (!userSearchQuery || userSearchQuery.length < 2) return [];
      const { data, error } = await supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url")
        .or(`username.ilike.%${userSearchQuery}%,full_name.ilike.%${userSearchQuery}%,email.ilike.%${userSearchQuery}%`)
        .limit(8);

      if (error) throw error;
      return data || [];
    },
    enabled: !isBroadcast && userSearchQuery.length >= 2,
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
          [root.sender_id, root.recipient_id, ...replies.flatMap((r: any) => [r.sender_id, r.recipient_id])].filter(Boolean)
        )
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, email, avatar_url")
        .in("id", allUserIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      const enrichedRoot = {
        ...root,
        sender: profileMap.get(root.sender_id) || { id: root.sender_id, username: "Admin", email: "" },
        recipient: root.recipient_id ? profileMap.get(root.recipient_id) || { id: root.recipient_id, username: "User", email: "" } : null,
      };

      const enrichedReplies = replies.map((r: any) => ({
        ...r,
        sender: profileMap.get(r.sender_id) || { id: r.sender_id, username: "User", email: "" },
        recipient: r.recipient_id ? profileMap.get(r.recipient_id) || { id: r.recipient_id, username: "Recipient", email: "" } : null,
      }));

      return { root: enrichedRoot, replies: enrichedReplies };
    },
    enabled: !!activeSheetThreadId,
  });

  // Send Message Mutation
  const sendMessageMutation = useMutation({
    mutationFn: async () => {
      if (!isBroadcast && !selectedUser) {
        throw new Error("Please select a recipient for direct message.");
      }
      if (!body.trim()) {
        throw new Error("Message body is required.");
      }

      const { data, error } = await supabase.rpc("send_admin_message", {
        p_recipient_id: isBroadcast ? null : selectedUser.id,
        p_subject: subject.trim(),
        p_body: body.trim(),
        p_allow_replies: allowReplies,
        p_is_broadcast: isBroadcast,
      });

      if (error) throw error;
      const res = data as any;
      if (!res.success) throw new Error(res.message || "Failed to send message");
      return res;
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

  // Staff Reply Mutation
  const staffReplyMutation = useMutation({
    mutationFn: async (text: string) => {
      if (!activeSheetThreadId) throw new Error("No active thread");
      const { data, error } = await supabase.rpc("send_message_reply", {
        p_parent_id: activeSheetThreadId,
        p_body: text.trim(),
      });

      if (error) throw error;
      const res = data as any;
      if (!res.success) throw new Error(res.message || "Failed to post reply");
      return res;
    },
    onSuccess: () => {
      setStaffReplyText("");
      queryClient.invalidateQueries({ queryKey: ["admin-thread-detail", activeSheetThreadId] });
      queryClient.invalidateQueries({ queryKey: ["admin-messages-threads"] });
      toast.success("Staff reply posted!");
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
    if (filterType === "direct" && t.is_broadcast) return false;
    if (filterType === "broadcast" && !t.is_broadcast) return false;

    if (searchFilter.trim()) {
      const q = searchFilter.toLowerCase();
      const matchSubject = t.subject?.toLowerCase().includes(q);
      const matchBody = t.body?.toLowerCase().includes(q);
      const matchUser =
        t.recipient?.username?.toLowerCase().includes(q) ||
        t.recipient?.email?.toLowerCase().includes(q) ||
        t.recipient?.full_name?.toLowerCase().includes(q);
      return matchSubject || matchBody || matchUser;
    }
    return true;
  });

  const directCount = threads.filter((t: any) => !t.is_broadcast).length;
  const broadcastCount = threads.filter((t: any) => t.is_broadcast).length;

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
            Send direct communications to users or broadcast global platform announcements with
            granular reply permissions.
          </p>
        </div>

        <Button
          onClick={() => {
            resetComposeForm();
            setIsComposeOpen(true);
          }}
          className="h-11 px-5 rounded-2xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none shadow-md shadow-gold/20 gap-2 shrink-0"
        >
          <Plus className="size-4" />
          <span>New Message / Announcement</span>
        </Button>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Total Conversations</p>
          <p className="text-2xl font-black text-ink-fg font-mono">{threads.length}</p>
        </div>
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Direct Messages to Members</p>
          <p className="text-2xl font-black text-gold font-mono">{directCount}</p>
        </div>
        <div className="p-4 rounded-2xl bg-ink-2/40 border border-hairline space-y-1">
          <p className="text-xs text-ink-muted font-medium">Broadcast Announcements</p>
          <p className="text-2xl font-black text-amber-400 font-mono">{broadcastCount}</p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 p-1 bg-ink-2/80 rounded-2xl border border-hairline w-full sm:w-auto">
          <button
            type="button"
            onClick={() => setFilterType("all")}
            className={cn(
              "px-4 py-1.5 rounded-xl text-xs font-bold transition-all",
              filterType === "all" ? "bg-gold text-ink shadow-sm" : "text-ink-muted hover:text-ink-fg",
            )}
          >
            All Threads ({threads.length})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("direct")}
            className={cn(
              "px-4 py-1.5 rounded-xl text-xs font-bold transition-all",
              filterType === "direct" ? "bg-gold text-ink shadow-sm" : "text-ink-muted hover:text-ink-fg",
            )}
          >
            Direct ({directCount})
          </button>
          <button
            type="button"
            onClick={() => setFilterType("broadcast")}
            className={cn(
              "px-4 py-1.5 rounded-xl text-xs font-bold transition-all",
              filterType === "broadcast" ? "bg-gold text-ink shadow-sm" : "text-ink-muted hover:text-ink-fg",
            )}
          >
            Broadcasts ({broadcastCount})
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
            {filteredThreads.map((thread: any) => (
              <div
                key={thread.id}
                className="p-4 sm:p-5 hover:bg-ink-2/60 transition-colors flex flex-col sm:flex-row sm:items-center justify-between gap-4"
              >
                <div className="flex items-start gap-3.5 min-w-0">
                  <Avatar className="size-10 rounded-xl border border-hairline shrink-0 bg-ink-2">
                    <AvatarImage src={thread.recipient?.avatar_url || ""} />
                    <AvatarFallback className="bg-gold/15 text-gold font-bold text-xs">
                      {thread.is_broadcast ? <Megaphone className="size-4" /> : <User className="size-4" />}
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
                    className="h-9 px-4 rounded-xl font-bold text-xs border-hairline bg-ink-2/80 hover:bg-gold/15 hover:text-gold hover:border-gold/40 gap-1.5 transition-all"
                  >
                    <Eye className="size-3.5" />
                    <span>View Conversation</span>
                  </Button>
                </div>
              </div>
            ))}
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
                      className="text-xs text-rose-400 hover:bg-rose-500/10 h-7 px-2"
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
                      <p className="text-[11px] text-ink-muted px-1">Searching users...</p>
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
                            className="w-full text-left p-2 rounded-lg hover:bg-gold/15 flex items-center justify-between gap-2 text-xs transition-colors"
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
                    ) : userSearchQuery.length >= 2 ? (
                      <p className="text-[11px] text-ink-muted px-1">No users found.</p>
                    ) : null}
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
              disabled={sendMessageMutation.isPending || (!isBroadcast && !selectedUser) || !body.trim()}
              className="h-10 px-5 rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none gap-2 shadow-md"
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
      <Sheet open={!!activeSheetThreadId} onOpenChange={(open) => !open && setActiveSheetThreadId(null)}>
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
              ) : (
                <Badge className="text-[9px] bg-gold/10 border-gold/30 text-gold">
                  Direct: @{threadDetail?.root?.recipient?.username || "User"}
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
                      {threadDetail.root.sender?.username || "Administrator"} (Initial Message)
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
                        @{reply.sender?.username || "User"}
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
              placeholder="Type staff response to user..."
              value={staffReplyText}
              onChange={(e) => setStaffReplyText(e.target.value)}
              rows={3}
              className="bg-ink border-hairline rounded-xl text-xs resize-none p-3 focus-visible:ring-gold"
            />
            <div className="flex items-center justify-end">
              <Button
                onClick={() => staffReplyMutation.mutate(staffReplyText)}
                disabled={!staffReplyText.trim() || staffReplyMutation.isPending}
                className="h-9 px-5 rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none gap-2 shadow-md"
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
