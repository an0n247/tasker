import { createFileRoute, useNavigate, useSearch } from "@tanstack/react-router";
import { useState, useEffect, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/hooks/use-auth";
import {
  Mail,
  Send,
  Sparkles,
  Shield,
  Megaphone,
  CheckCircle2,
  Clock,
  ArrowLeft,
  MessageSquare,
  Lock,
  Search,
  Filter,
  User,
  AlertCircle,
  Inbox,
  Radio,
  CornerDownRight,
  Check,
} from "lucide-react";
import { formatDistanceToNow, format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { toast } from "sonner";
import { motion, AnimatePresence } from "framer-motion";
import { cn } from "@/lib/utils";

interface MessagesSearchParams {
  messageId?: string;
}

export const Route = createFileRoute("/_authenticated/messages")({
  validateSearch: (search: Record<string, unknown>): MessagesSearchParams => {
    return {
      messageId: typeof search.messageId === "string" ? search.messageId : undefined,
    };
  },
  head: () => ({
    title: "Inbox & Messages | Noble Gain",
    meta: [
      {
        name: "description",
        content: "Official communications, announcements, and direct messages from the Noble Gain team.",
      },
    ],
  }),
  component: MessagesPage,
});

export function MessagesPage() {
  const { user } = useAuth();
  const search = useSearch({ from: "/_authenticated/messages" });
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [selectedThreadId, setSelectedThreadId] = useState<string | null>(search.messageId || null);
  const [filterType, setFilterType] = useState<"all" | "direct" | "broadcasts">("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [replyText, setReplyText] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Sync selected thread from URL if changed externally
  useEffect(() => {
    if (search.messageId && search.messageId !== selectedThreadId) {
      setSelectedThreadId(search.messageId);
    }
  }, [search.messageId]);

  // Fetch Threads (Root Messages)
  const { data: threads = [], isLoading: isLoadingThreads } = useQuery({
    queryKey: ["messages-threads", user?.id],
    queryFn: async () => {
      if (!user) return [];

      // Fetch all root messages (parent_id IS NULL) that the user is entitled to view
      const { data: rawMessages, error } = await supabase
        .from("messages" as any)
        .select("*")
        .is("parent_id", null)
        .order("updated_at", { ascending: false });

      if (error) {
        console.error("Error fetching messages:", error);
        return [];
      }

      const msgs = (rawMessages || []) as any[];
      if (msgs.length === 0) return [];

      // Fetch sender & recipient profiles
      const userIds = Array.from(
        new Set(
          msgs.flatMap((m: any) => [m.sender_id, m.recipient_id]).filter(Boolean)
        )
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, avatar_url")
        .in("id", userIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      // Fetch message_reads for broadcasts
      const { data: reads } = await supabase
        .from("message_reads" as any)
        .select("message_id")
        .eq("user_id", user.id);

      const readSet = new Set((reads || []).map((r: any) => r.message_id));

      return msgs.map((msg: any) => ({
        ...msg,
        sender: profileMap.get(msg.sender_id) || { id: msg.sender_id, username: "Administration" },
        recipient: msg.recipient_id ? profileMap.get(msg.recipient_id) || null : null,
        isReadForUser: msg.is_broadcast ? readSet.has(msg.id) : (msg.is_read || msg.sender_id === user.id),
      }));
    },
    enabled: !!user,
  });

  // Automatically select first thread on desktop if none selected
  useEffect(() => {
    if (!selectedThreadId && threads.length > 0 && typeof window !== "undefined" && window.innerWidth >= 1024) {
      setSelectedThreadId(threads[0].id);
    }
  }, [threads, selectedThreadId]);

  // Fetch Active Thread Detail and Replies
  const { data: activeThreadData, isLoading: isLoadingThreadDetail } = useQuery({
    queryKey: ["message-thread-detail", selectedThreadId],
    queryFn: async () => {
      if (!selectedThreadId) return null;

      // 1. Fetch Root Message and Replies
      const [{ data: rootRaw }, { data: repliesRaw }] = await Promise.all([
        supabase
          .from("messages" as any)
          .select("*")
          .eq("id", selectedThreadId)
          .maybeSingle(),
        supabase
          .from("messages" as any)
          .select("*")
          .eq("parent_id", selectedThreadId)
          .order("created_at", { ascending: true }),
      ]);

      if (!rootRaw) return null;

      const root = rootRaw as any;
      const replies = (repliesRaw || []) as any[];

      // Collect all user IDs from root and replies
      const allUserIds = Array.from(
        new Set(
          [root.sender_id, root.recipient_id, ...replies.flatMap((r: any) => [r.sender_id, r.recipient_id])].filter(Boolean)
        )
      );

      const { data: profiles } = await supabase
        .from("profiles")
        .select("id, username, full_name, avatar_url")
        .in("id", allUserIds);

      const profileMap = new Map((profiles || []).map((p: any) => [p.id, p]));

      const enrichedRoot = {
        ...root,
        sender: profileMap.get(root.sender_id) || { id: root.sender_id, username: "Administration" },
        recipient: root.recipient_id ? profileMap.get(root.recipient_id) || null : null,
      };

      const enrichedReplies = replies.map((r: any) => ({
        ...r,
        sender: profileMap.get(r.sender_id) || { id: r.sender_id, username: "Member" },
        recipient: r.recipient_id ? profileMap.get(r.recipient_id) || null : null,
      }));

      return {
        root: enrichedRoot,
        replies: enrichedReplies,
      };
    },
    enabled: !!selectedThreadId,
  });

  // Mark active thread as read
  useEffect(() => {
    if (selectedThreadId && user) {
      supabase.rpc("mark_message_read", { p_message_id: selectedThreadId }).then(() => {
        queryClient.invalidateQueries({ queryKey: ["unread-messages-count"] });
        queryClient.invalidateQueries({ queryKey: ["messages-threads"] });
      });
    }
  }, [selectedThreadId, user]);

  // Scroll to bottom of conversation
  useEffect(() => {
    if (activeThreadData) {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [activeThreadData?.replies]);

  // Realtime subscription for incoming messages and replies
  useEffect(() => {
    if (!user) return;

    const channel = supabase
      .channel("messages-realtime")
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "messages",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["messages-threads"] });
          queryClient.invalidateQueries({ queryKey: ["message-thread-detail", selectedThreadId] });
          queryClient.invalidateQueries({ queryKey: ["unread-messages-count"] });
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user, selectedThreadId]);

  // Send Reply Mutation
  const sendReplyMutation = useMutation({
    mutationFn: async (text: string) => {
      if (!selectedThreadId) throw new Error("No conversation selected");
      const { data, error } = await supabase.rpc("send_message_reply", {
        p_parent_id: selectedThreadId,
        p_body: text.trim(),
      });

      if (error) throw error;
      const res = data as any;
      if (!res.success) throw new Error(res.message || "Failed to send reply");
      return res;
    },
    onSuccess: () => {
      setReplyText("");
      queryClient.invalidateQueries({ queryKey: ["message-thread-detail", selectedThreadId] });
      queryClient.invalidateQueries({ queryKey: ["messages-threads"] });
      toast.success("Reply sent successfully");
    },
    onError: (err: any) => {
      toast.error(err.message || "Could not send reply.");
    },
  });

  const handleSendReply = (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyText.trim() || sendReplyMutation.isPending) return;
    sendReplyMutation.mutate(replyText);
  };

  const handleSelectThread = (threadId: string) => {
    setSelectedThreadId(threadId);
    navigate({
      to: "/messages",
      search: { messageId: threadId },
    });
  };

  // Filter threads
  const filteredThreads = threads.filter((t: any) => {
    if (filterType === "direct" && t.is_broadcast) return false;
    if (filterType === "broadcasts" && !t.is_broadcast) return false;

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      const subjectMatch = t.subject?.toLowerCase().includes(q);
      const bodyMatch = t.body?.toLowerCase().includes(q);
      const senderMatch = t.sender?.username?.toLowerCase().includes(q) || t.sender?.full_name?.toLowerCase().includes(q);
      return subjectMatch || bodyMatch || senderMatch;
    }
    return true;
  });

  const activeRoot = activeThreadData?.root;
  const isRepliesAllowed = activeRoot?.allow_replies ?? true;

  return (
    <div className="w-full max-w-7xl mx-auto pb-16 space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-hairline/80 pb-6">
        <div className="space-y-1.5">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Mail className="size-3.5" />
            <span>Communications Hub</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Official Inbox</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black tracking-tight text-ink-fg">
            Messages & <span className="text-gold">Announcements</span>
          </h1>
          <p className="text-xs sm:text-sm font-medium text-ink-muted">
            Official communications, platform notices, and direct messages from the administration.
          </p>
        </div>
      </div>

      {/* Main Inbox Interface Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 min-h-[640px] bg-ink-2/40 border border-hairline rounded-3xl p-3 sm:p-4 shadow-xl backdrop-blur-xl">
        {/* Left Column: Threads List (hidden on mobile if thread is active) */}
        <div
          className={cn(
            "lg:col-span-5 flex flex-col space-y-4 rounded-2xl bg-ink/80 border border-hairline/70 p-4 transition-all",
            selectedThreadId ? "hidden lg:flex" : "flex",
          )}
        >
          {/* Search & Filter Bar */}
          <div className="space-y-3">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-ink-muted" />
              <Input
                placeholder="Search messages, subjects, team..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 h-10 bg-ink-2/80 border-hairline rounded-xl text-xs"
              />
            </div>

            {/* Filter Pills */}
            <div className="flex items-center gap-1.5 p-1 bg-ink-2/60 rounded-xl border border-hairline">
              <button
                type="button"
                onClick={() => setFilterType("all")}
                className={cn(
                  "flex-1 py-1.5 rounded-lg text-xs font-bold transition-all text-center",
                  filterType === "all"
                    ? "bg-gold text-ink shadow-sm font-black"
                    : "text-ink-muted hover:text-ink-fg",
                )}
              >
                All
              </button>
              <button
                type="button"
                onClick={() => setFilterType("direct")}
                className={cn(
                  "flex-1 py-1.5 rounded-lg text-xs font-bold transition-all text-center",
                  filterType === "direct"
                    ? "bg-gold text-ink shadow-sm font-black"
                    : "text-ink-muted hover:text-ink-fg",
                )}
              >
                Direct
              </button>
              <button
                type="button"
                onClick={() => setFilterType("broadcasts")}
                className={cn(
                  "flex-1 py-1.5 rounded-lg text-xs font-bold transition-all text-center",
                  filterType === "broadcasts"
                    ? "bg-gold text-ink shadow-sm font-black"
                    : "text-ink-muted hover:text-ink-fg",
                )}
              >
                Announcements
              </button>
            </div>
          </div>

          {/* Threads Scroll List */}
          <ScrollArea className="flex-1 -mx-2 px-2 max-h-[520px]">
            {isLoadingThreads ? (
              <div className="py-12 text-center text-xs text-ink-muted space-y-2">
                <div className="size-6 border-2 border-gold border-t-transparent rounded-full animate-spin mx-auto" />
                <p>Loading messages...</p>
              </div>
            ) : filteredThreads.length === 0 ? (
              <div className="py-16 text-center text-ink-muted space-y-3 px-4">
                <div className="size-12 rounded-2xl bg-ink-2 border border-hairline flex items-center justify-center mx-auto text-ink-muted">
                  <Inbox className="size-6" />
                </div>
                <div className="space-y-1">
                  <p className="text-sm font-bold text-ink-fg">No messages found</p>
                  <p className="text-xs text-ink-muted">
                    {searchQuery
                      ? "No messages matching your search query."
                      : "You don't have any messages in this category yet."}
                  </p>
                </div>
              </div>
            ) : (
              <div className="space-y-2">
                {filteredThreads.map((thread: any) => {
                  const isSelected = selectedThreadId === thread.id;
                  const isUnread = !thread.isReadForUser;

                  return (
                    <button
                      key={thread.id}
                      type="button"
                      onClick={() => handleSelectThread(thread.id)}
                      className={cn(
                        "w-full text-left p-3.5 rounded-2xl border transition-all relative group flex flex-col space-y-2",
                        isSelected
                          ? "bg-gold/15 border-gold text-ink-fg shadow-md ring-1 ring-gold/30"
                          : isUnread
                            ? "bg-ink-2/90 border-hairline hover:bg-ink-3 hover:border-gold/30"
                            : "bg-ink-2/40 border-hairline/60 hover:bg-ink-2/70 text-ink-muted",
                      )}
                    >
                      {/* Top Row: Sender Badge & Date */}
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2">
                          {thread.is_broadcast ? (
                            <Badge
                              variant="outline"
                              className="text-[10px] px-2 py-0.5 font-black bg-amber-500/10 border-amber-500/30 text-amber-400 gap-1"
                            >
                              <Megaphone className="size-3" />
                              Announcement
                            </Badge>
                          ) : (
                            <Badge
                              variant="outline"
                              className="text-[10px] px-2 py-0.5 font-bold bg-gold/10 border-gold/30 text-gold gap-1"
                            >
                              <Shield className="size-3" />
                              Admin Notice
                            </Badge>
                          )}

                          {isUnread && (
                            <span className="size-2 rounded-full bg-gold animate-pulse" />
                          )}
                        </div>

                        <span className="text-[10px] text-ink-muted font-mono">
                          {formatDistanceToNow(new Date(thread.updated_at || thread.created_at), {
                            addSuffix: true,
                          })}
                        </span>
                      </div>

                      {/* Subject */}
                      <h4
                        className={cn(
                          "text-xs font-black tracking-tight line-clamp-1",
                          isSelected ? "text-gold" : isUnread ? "text-ink-fg" : "text-ink-muted",
                        )}
                      >
                        {thread.subject || "Administrative Notice"}
                      </h4>

                      {/* Body Snippet */}
                      <p className="text-[11px] text-ink-muted line-clamp-2 leading-relaxed">
                        {thread.body}
                      </p>

                      {/* Bottom indicator */}
                      <div className="flex items-center justify-between pt-1 text-[10px]">
                        <span className="text-ink-muted/80 flex items-center gap-1">
                          {thread.allow_replies ? (
                            <span className="text-emerald-400 flex items-center gap-1 font-medium">
                              <MessageSquare className="size-3" />
                              Replies Allowed
                            </span>
                          ) : (
                            <span className="text-ink-muted flex items-center gap-1">
                              <Lock className="size-3" />
                              Read-Only
                            </span>
                          )}
                        </span>
                      </div>
                    </button>
                  );
                })}
              </div>
            )}
          </ScrollArea>
        </div>

        {/* Right Column: Active Thread Conversation View */}
        <div
          className={cn(
            "lg:col-span-7 flex flex-col rounded-2xl bg-ink/90 border border-hairline/80 p-4 sm:p-6 transition-all min-h-[550px]",
            !selectedThreadId ? "hidden lg:flex items-center justify-center text-center" : "flex",
          )}
        >
          {!selectedThreadId ? (
            <div className="space-y-3 p-8 text-center max-w-sm">
              <div className="size-14 rounded-3xl bg-gold/10 border border-gold/20 flex items-center justify-center mx-auto text-gold">
                <Mail className="size-7" />
              </div>
              <h3 className="text-base font-black text-ink-fg">Select a message</h3>
              <p className="text-xs text-ink-muted leading-relaxed">
                Choose a conversation from the left to read official announcements, directives, and
                replies from the Noble Gain leadership team.
              </p>
            </div>
          ) : isLoadingThreadDetail ? (
            <div className="flex-1 flex flex-col items-center justify-center gap-3 text-ink-muted">
              <div className="size-8 border-2 border-gold border-t-transparent rounded-full animate-spin" />
              <p className="text-xs font-bold">Loading conversation...</p>
            </div>
          ) : !activeRoot ? (
            <div className="flex-1 flex flex-col items-center justify-center gap-3 text-ink-muted">
              <AlertCircle className="size-8 text-rose-400" />
              <p className="text-sm font-bold text-ink-fg">Message not found</p>
              <Button
                variant="outline"
                size="sm"
                onClick={() => setSelectedThreadId(null)}
                className="text-xs"
              >
                Back to Inbox
              </Button>
            </div>
          ) : (
            <div className="flex-1 flex flex-col h-full justify-between space-y-4">
              {/* Conversation Header */}
              <div className="flex items-start justify-between gap-3 pb-4 border-b border-hairline">
                <div className="flex items-center gap-3">
                  <button
                    type="button"
                    onClick={() => setSelectedThreadId(null)}
                    className="lg:hidden p-2 rounded-xl bg-ink-2 text-ink-muted hover:text-ink-fg border border-hairline"
                  >
                    <ArrowLeft className="size-4" />
                  </button>

                  <Avatar className="size-10 rounded-xl border border-gold/30 bg-ink-2">
                    <AvatarImage src={activeRoot.sender?.avatar_url || ""} />
                    <AvatarFallback className="bg-gold/15 text-gold font-bold text-xs">
                      {activeRoot.is_broadcast ? <Megaphone className="size-4" /> : <Shield className="size-4" />}
                    </AvatarFallback>
                  </Avatar>

                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="text-sm font-black text-ink-fg">
                        {activeRoot.subject || "Administrative Notice"}
                      </h3>
                      {activeRoot.is_broadcast ? (
                        <Badge
                          variant="outline"
                          className="text-[9px] bg-amber-500/10 border-amber-500/30 text-amber-400 font-bold"
                        >
                          Broadcast
                        </Badge>
                      ) : (
                        <Badge
                          variant="outline"
                          className="text-[9px] bg-gold/10 border-gold/30 text-gold font-bold"
                        >
                          Official
                        </Badge>
                      )}
                    </div>
                    <p className="text-[11px] text-ink-muted font-medium">
                      From:{" "}
                      <strong className="text-ink-fg">
                        {activeRoot.sender?.full_name || activeRoot.sender?.username || "Noble Gain Team"}
                      </strong>{" "}
                      • {format(new Date(activeRoot.created_at), "MMM d, yyyy h:mm a")}
                    </p>
                  </div>
                </div>

                <div>
                  {isRepliesAllowed ? (
                    <Badge
                      variant="outline"
                      className="text-[10px] bg-emerald-500/10 border-emerald-500/30 text-emerald-400 font-bold"
                    >
                      Replies Open
                    </Badge>
                  ) : (
                    <Badge
                      variant="outline"
                      className="text-[10px] bg-slate-500/10 border-slate-500/30 text-slate-400 font-bold"
                    >
                      Replies Disabled
                    </Badge>
                  )}
                </div>
              </div>

              {/* Scrollable Conversation Stream */}
              <ScrollArea className="flex-1 pr-3 max-h-[420px]">
                <div className="space-y-4 py-2">
                  {/* Root Admin Message Bubble */}
                  <div className="p-4 sm:p-5 rounded-2xl bg-ink-2/80 border border-gold/20 space-y-2.5 shadow-sm">
                    <div className="flex items-center justify-between text-xs">
                      <span className="font-bold text-gold flex items-center gap-1.5">
                        <Shield className="size-3.5" />
                        {activeRoot.sender?.username || "System Administration"}
                      </span>
                      <span className="text-[10px] text-ink-muted font-mono">
                        {formatDistanceToNow(new Date(activeRoot.created_at), { addSuffix: true })}
                      </span>
                    </div>

                    <p className="text-xs sm:text-sm text-ink-fg leading-relaxed whitespace-pre-wrap">
                      {activeRoot.body}
                    </p>
                  </div>

                  {/* Replies Stream */}
                  {activeThreadData.replies.map((reply: any) => {
                    const isCurrentUser = reply.sender_id === user?.id;

                    return (
                      <div
                        key={reply.id}
                        className={cn(
                          "flex flex-col max-w-[88%] space-y-1",
                          isCurrentUser ? "ml-auto items-end" : "mr-auto items-start",
                        )}
                      >
                        <div className="flex items-center gap-2 text-[10px] text-ink-muted px-1">
                          <span className="font-bold">
                            {isCurrentUser ? "You" : reply.sender?.username || "Support Staff"}
                          </span>
                          <span>•</span>
                          <span className="font-mono">
                            {formatDistanceToNow(new Date(reply.created_at), { addSuffix: true })}
                          </span>
                        </div>

                        <div
                          className={cn(
                            "p-3.5 sm:p-4 rounded-2xl text-xs sm:text-sm leading-relaxed whitespace-pre-wrap border",
                            isCurrentUser
                              ? "bg-gradient-to-r from-gold/25 to-gold/10 text-ink-fg border-gold/40 rounded-tr-sm"
                              : "bg-ink-2 border-hairline text-ink-fg rounded-tl-sm",
                          )}
                        >
                          {reply.body}
                        </div>
                      </div>
                    );
                  })}

                  <div ref={messagesEndRef} />
                </div>
              </ScrollArea>

              {/* Bottom Section: Reply Composer OR Read-Only Notice */}
              <div className="pt-3 border-t border-hairline">
                {isRepliesAllowed ? (
                  <form onSubmit={handleSendReply} className="space-y-2.5">
                    <div className="relative">
                      <Textarea
                        placeholder="Write your reply to this message... (Press Shift+Enter for newline)"
                        value={replyText}
                        onChange={(e) => setReplyText(e.target.value)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" && !e.shiftKey) {
                            e.preventDefault();
                            handleSendReply(e);
                          }
                        }}
                        rows={3}
                        className="bg-ink-2/90 border-hairline rounded-2xl text-xs p-3.5 focus-visible:ring-gold resize-none"
                      />
                    </div>

                    <div className="flex items-center justify-between">
                      <p className="text-[11px] text-ink-muted font-medium">
                        Only administrators and you can see this thread.
                      </p>

                      <Button
                        type="submit"
                        disabled={!replyText.trim() || sendReplyMutation.isPending}
                        className="h-9 px-5 rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft border-none gap-1.5 shadow-md"
                      >
                        {sendReplyMutation.isPending ? (
                          "Sending..."
                        ) : (
                          <>
                            <span>Send Reply</span>
                            <Send className="size-3.5" />
                          </>
                        )}
                      </Button>
                    </div>
                  </form>
                ) : (
                  <div className="p-4 rounded-2xl bg-ink-2/60 border border-hairline flex items-center gap-3 text-ink-muted">
                    <div className="size-8 rounded-xl bg-ink-3 border border-hairline flex items-center justify-center shrink-0">
                      <Lock className="size-4 text-ink-muted" />
                    </div>
                    <div className="text-xs space-y-0.5">
                      <p className="font-bold text-ink-fg">Replies are disabled for this message</p>
                      <p className="text-[11px] text-ink-muted">
                        This is an official administrative notice. No further user action or reply
                        is required.
                      </p>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
