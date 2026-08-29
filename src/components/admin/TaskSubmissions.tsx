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
import { toast } from "sonner";
import {
  CheckCircle2,
  XCircle,
  Clock,
  User,
  ListTodo,
  Loader2,
  Inbox,
  History,
  ShieldCheck,
  MessageSquare,
  RotateCcw,
} from "lucide-react";
import { format } from "date-fns";
import { useEffect, useMemo, useState } from "react";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";

type FilterValue = "pending" | "verified" | "rejected" | "all";

const FILTERS: { value: FilterValue; label: string; icon: typeof Clock }[] = [
  { value: "pending", label: "Pending Approval", icon: Inbox },
  { value: "verified", label: "Completed", icon: CheckCircle2 },
  { value: "rejected", label: "Rejected", icon: XCircle },
  { value: "all", label: "All History", icon: History },
];

export function TaskSubmissions() {
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<FilterValue>("pending");
  const [adminNotes, setAdminNotes] = useState<Record<string, string>>({});
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [noteTarget, setNoteTarget] = useState<{
    submissionId: string;
    userId?: string;
    userName: string;
    taskTitle: string;
  } | null>(null);
  const [noteMessage, setNoteMessage] = useState("");
  const [removeTask, setRemoveTask] = useState(false);

  const closeNoteDialog = () => {
    setNoteTarget(null);
    setNoteMessage("");
    setRemoveTask(false);
  };

  const sendNoteMutation = useMutation({
    mutationFn: async ({ userId, message, taskTitle }: { userId: string; message: string; taskTitle: string }) => {
      const { data, error } = await (supabase.rpc as any)("send_user_notification", {
        _user_id: userId,
        _title: `Note about "${taskTitle}"`,
        _message: message,
        _type: "info",
        _metadata: {},
      });
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      toast.success("Note sent to the user");
      closeNoteDialog();
    },
    onError: (error: any) => toast.error(error.message || "Failed to send note"),
  });

  const revokeMutation = useMutation({
    mutationFn: async ({ submissionId, note }: { submissionId: string; note: string }) => {
      const { data, error } = await (supabase.rpc as any)("admin_revoke_task_submission", {
        _submission_id: submissionId,
        _admin_note: note || null,
      });
      if (error) throw error;
      if (data && (data as any).success === false)
        throw new Error((data as any).message || "Failed to remove task");
      return data as any;
    },
    onSuccess: (data) => {
      toast.success(
        `Task removed and reset for the user${data?.points_removed ? ` (${data.points_removed} points reversed)` : ""}`,
      );
      closeNoteDialog();
      queryClient.invalidateQueries({ queryKey: ["admin-task-submissions"] });
      queryClient.invalidateQueries({ queryKey: ["admin-submission-counts"] });
    },
    onError: (error: any) => toast.error(error.message || "Failed to remove task"),
  });


  const { data: counts } = useQuery({
    queryKey: ["admin-submission-counts"],
    queryFn: async () => {
      const { data, error } = await supabase.from("task_submissions").select("status");
      if (error) throw error;
      const tally: Record<FilterValue, number> = { pending: 0, verified: 0, rejected: 0, all: 0 };
      data?.forEach((row) => {
        const status = row.status as FilterValue;
        if (status in tally) tally[status] += 1;
      });
      tally.all = tally.pending + tally.verified + tally.rejected;
      return tally;
    },
  });

  const { data: submissions, isLoading } = useQuery({
    queryKey: ["admin-task-submissions", filter],
    queryFn: async () => {
      let query = supabase
        .from("task_submissions")
        .select(
          `
          id,
          status,
          admin_note,
          created_at,
          verified_at,
          tasks (id, title, points, category),
          profiles (id, full_name, username)
        `,
        )
        .order(filter === "pending" ? "created_at" : "verified_at", {
          ascending: filter === "pending",
          nullsFirst: false,
        })
        .limit(200);

      if (filter !== "all") {
        query = query.eq("status", filter);
      }

      const { data, error } = await query;
      if (error) {
        console.error("Error fetching submissions:", error);
        throw error;
      }
      return data as any[];
    },
  });

  useEffect(() => {
    const channel = supabase
      .channel("admin-submissions-realtime")
      .on("postgres_changes", { event: "*", schema: "public", table: "task_submissions" }, () => {
        queryClient.invalidateQueries({ queryKey: ["admin-task-submissions"] });
        queryClient.invalidateQueries({ queryKey: ["admin-submission-counts"] });
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  const verifyMutation = useMutation({
    mutationFn: async ({ id, approve }: { id: string; approve: boolean }) => {
      setProcessingId(id);
      const note = adminNotes[id] || "";
      const { data, error } = await (supabase.rpc as any)("verify_task_submission", {
        _submission_id: id,
        _approve: approve,
        _admin_note: note,
      });

      if (error) throw error;
      if (data && !data.success) throw new Error(data.message);
      return data;
    },
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["admin-task-submissions"] });
      queryClient.invalidateQueries({ queryKey: ["admin-submission-counts"] });
      queryClient.invalidateQueries({ queryKey: ["adminStats"] });
      toast.success(data.message || "Task verification processed");
      setAdminNotes((prev) => {
        const next = { ...prev };
        delete next[variables.id];
        return next;
      });
      setProcessingId(null);
    },
    onError: (error: any) => {
      toast.error(error.message || "Error processing verification");
      setProcessingId(null);
    },
  });

  const emptyMessage = useMemo(() => {
    switch (filter) {
      case "pending":
        return "No pending verifications at the moment.";
      case "verified":
        return "No completed tasks yet.";
      case "rejected":
        return "No rejected submissions yet.";
      default:
        return "No submissions recorded yet.";
    }
  }, [filter]);


  const statusBadge = (status: string) => {
    if (status === "verified" || status === "approved") {
      return (
        <Badge className="bg-green-500/10 text-green-600 border-green-500/20 text-[9px] font-black uppercase px-1.5 h-5">
          <CheckCircle2 className="h-3 w-3 mr-1" /> Completed
        </Badge>
      );
    }
    if (status === "rejected") {
      return (
        <Badge className="bg-destructive/10 text-destructive border-destructive/20 text-[9px] font-black uppercase px-1.5 h-5">
          <XCircle className="h-3 w-3 mr-1" /> Rejected
        </Badge>
      );
    }
    return (
      <Badge className="bg-amber-500/10 text-amber-600 border-amber-500/20 text-[9px] font-black uppercase px-1.5 h-5">
        <Clock className="h-3 w-3 mr-1" /> Pending
      </Badge>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
          <ShieldCheck className="h-5 w-5 text-primary" />
          Task Submissions
        </h3>
        <p className="text-sm text-muted-foreground font-medium">
          Review tasks done by users — approve pending work and browse completed history.
        </p>
      </div>

      {/* Status filter — tabbed on all sizes */}
      <div className="flex flex-col gap-4">
        <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1 sm:flex-wrap sm:overflow-visible">
          {FILTERS.map((f) => {
            const count = counts?.[f.value] ?? 0;
            return (
              <button
                key={f.value}
                onClick={() => setFilter(f.value)}
                className={cn(
                  "flex shrink-0 items-center gap-2 rounded-xl border px-4 py-2.5 text-[10px] font-black uppercase tracking-widest transition-all duration-300",
                  filter === f.value
                    ? "bg-primary text-primary-foreground shadow-lg shadow-primary/20 border-transparent"
                    : "bg-card/50 text-muted-foreground border-border/40 hover:bg-primary/5 hover:text-primary",
                )}
              >
                <f.icon className="h-4 w-4" />
                {f.label}
                <span
                  className={cn(
                    "ml-1 rounded-md px-1.5 py-0.5 text-[9px]",
                    filter === f.value
                      ? "bg-primary-foreground/20"
                      : "bg-primary/10 text-primary",
                  )}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>
      </div>


      {isLoading ? (
        <div className="flex justify-center p-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : (
        <div className="rounded-2xl border border-border/50 bg-card overflow-hidden overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent border-border/50">
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                  User
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                  Task
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                  Status
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                  Submitted
                </TableHead>
                <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-right">
                  {filter === "pending" ? "Actions" : "Details"}
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {submissions?.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={5}
                    className="text-center py-12 text-muted-foreground font-medium"
                  >
                    {emptyMessage}
                  </TableCell>
                </TableRow>
              ) : (
                submissions?.map((sub) => (
                  <TableRow
                    key={sub.id}
                    className="border-border/40 hover:bg-accent/5 transition-colors"
                  >
                    <TableCell className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="h-8 w-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <User className="h-4 w-4 text-primary" />
                        </div>
                        <div>
                          <div className="font-bold text-sm">
                            {sub.profiles?.full_name || "Unknown User"}
                          </div>
                          <div className="text-[10px] text-muted-foreground uppercase font-black">
                            @{sub.profiles?.username || "unknown"}
                          </div>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <ListTodo className="h-4 w-4 text-muted-foreground shrink-0" />
                        <div>
                          <div className="font-bold text-sm">
                            {sub.tasks?.title || "Deleted Task"}
                          </div>
                          <div className="flex items-center gap-2 mt-0.5">
                            {sub.tasks?.points != null && (
                              <Badge
                                variant="outline"
                                className="text-[9px] font-black border-primary/20 text-primary px-1 h-4"
                              >
                                +{sub.tasks.points} PTS
                              </Badge>
                            )}
                            {sub.tasks?.category && (
                              <Badge
                                variant="secondary"
                                className="text-[9px] font-black px-1 h-4 uppercase"
                              >
                                {sub.tasks.category}
                              </Badge>
                            )}
                          </div>
                        </div>
                      </div>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      {statusBadge(sub.status)}
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      <div className="text-xs font-medium text-muted-foreground">
                        {sub.created_at ? format(new Date(sub.created_at), "MMM d, HH:mm") : "—"}
                      </div>
                      {sub.verified_at && sub.status !== "pending" && (
                        <div className="text-[10px] text-muted-foreground/70 font-medium mt-0.5">
                          Reviewed {format(new Date(sub.verified_at), "MMM d, HH:mm")}
                        </div>
                      )}
                    </TableCell>
                    <TableCell className="px-6 py-4 text-right">
                      {sub.status === "pending" ? (
                        <div className="flex flex-col gap-2 items-end">
                          <div className="flex items-center gap-2">
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-8 rounded-lg text-destructive hover:text-destructive hover:bg-destructive/5 font-bold text-xs"
                              onClick={() => verifyMutation.mutate({ id: sub.id, approve: false })}
                              disabled={processingId === sub.id}
                            >
                              {processingId === sub.id ? (
                                <Loader2 className="h-3 w-3 animate-spin mr-1" />
                              ) : (
                                <XCircle className="h-3 w-3 mr-1" />
                              )}
                              Reject
                            </Button>
                            <Button
                              size="sm"
                              className="h-8 rounded-lg bg-green-600 hover:bg-green-700 text-white font-bold text-xs"
                              onClick={() => verifyMutation.mutate({ id: sub.id, approve: true })}
                              disabled={processingId === sub.id}
                            >
                              {processingId === sub.id ? (
                                <Loader2 className="h-3 w-3 animate-spin mr-1" />
                              ) : (
                                <CheckCircle2 className="h-3 w-3 mr-1" />
                              )}
                              Approve
                            </Button>
                          </div>
                          <Input
                            placeholder="Add rejection reason..."
                            className="h-7 text-[10px] w-32 rounded-md"
                            value={adminNotes[sub.id] || ""}
                            onChange={(e) =>
                              setAdminNotes((prev) => ({ ...prev, [sub.id]: e.target.value }))
                            }
                          />
                        </div>
                      ) : (
                        <div className="flex flex-col items-end gap-2">
                          <div className="text-xs font-medium text-muted-foreground max-w-[220px] text-right">
                            {sub.admin_note ? (
                              <span className="italic">"{sub.admin_note}"</span>
                            ) : (
                              <span className="text-muted-foreground/60">No note</span>
                            )}
                          </div>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-8 rounded-lg font-bold text-xs"
                            onClick={() =>
                              setNoteTarget({
                                submissionId: sub.id,
                                userId: sub.profiles?.id,
                                userName: sub.profiles?.full_name || sub.profiles?.username || "user",
                                taskTitle: sub.tasks?.title || "Task",
                              })
                            }
                            disabled={!sub.profiles?.id}
                          >
                            <MessageSquare className="h-3 w-3 mr-1" />
                            Send Note
                          </Button>
                        </div>
                      )}

                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      )}

      <Dialog
        open={!!noteTarget}
        onOpenChange={(open) => {
          if (!open) {
            setNoteTarget(null);
            setNoteMessage("");
            setRemoveTask(false);
          }
        }}

      >
        <DialogContent className="rounded-2xl">
          <DialogHeader>
            <DialogTitle className="font-black uppercase tracking-tight">Send Note</DialogTitle>
            <DialogDescription>
              Send a message to {noteTarget?.userName} about "{noteTarget?.taskTitle}". They will
              receive it in their notifications.
            </DialogDescription>
          </DialogHeader>
          <Textarea
            placeholder="Write your note to the user..."
            value={noteMessage}
            onChange={(e) => setNoteMessage(e.target.value)}
            className="min-h-28 rounded-xl"
          />
          <label className="flex items-start gap-3 rounded-xl border border-border p-3 cursor-pointer">
            <Checkbox
              checked={removeTask}
              onCheckedChange={(checked) => setRemoveTask(checked === true)}
              className="mt-0.5"
            />
            <span className="text-xs">
              <span className="font-bold block">Remove the task</span>
              <span className="text-muted-foreground">
                Resets this task back to the user as a fresh task and removes the points credited
                for it.
              </span>
            </span>
          </label>
          <DialogFooter>
            <Button
              className="rounded-xl font-bold"
              variant={removeTask ? "destructive" : "default"}
              disabled={
                (!noteMessage.trim() && !removeTask) ||
                sendNoteMutation.isPending ||
                revokeMutation.isPending
              }
              onClick={() => {
                if (!noteTarget) return;
                if (removeTask) {
                  revokeMutation.mutate({
                    submissionId: noteTarget.submissionId,
                    note: noteMessage.trim(),
                  });
                } else if (noteTarget.userId) {
                  sendNoteMutation.mutate({
                    userId: noteTarget.userId,
                    message: noteMessage.trim(),
                    taskTitle: noteTarget.taskTitle,
                  });
                }
              }}
            >
              {sendNoteMutation.isPending || revokeMutation.isPending ? (
                <Loader2 className="h-4 w-4 animate-spin mr-1" />
              ) : removeTask ? (
                <RotateCcw className="h-4 w-4 mr-1" />
              ) : (
                <MessageSquare className="h-4 w-4 mr-1" />
              )}
              {removeTask ? "Remove Task & Notify" : "Send Note"}
            </Button>
          </DialogFooter>

        </DialogContent>
      </Dialog>
    </div>

  );
}
