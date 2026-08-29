import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  ShieldAlert,
  Loader2,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Clock,
  User,
  ExternalLink,
  Trash2,
} from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { format } from "date-fns";
import { toast } from "sonner";
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

export function FraudManager() {
  const queryClient = useQueryClient();

  const { data: flags, isLoading } = useQuery({
    queryKey: ["admin-fraud-flags"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("fraud_flags" as any)
        .select("*, profiles!fraud_flags_user_id_fkey(username, email, full_name)")
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data;
    },
  });

  const updateFlagStatus = useMutation({
    mutationFn: async ({ id, status }: { id: string; status: string }) => {
      const { error } = await supabase
        .from("fraud_flags" as any)
        .update({ status } as any)
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-fraud-flags"] });
      toast.success("Flag status updated");
    },
    onError: (err: any) => toast.error(err.message),
  });

  const deleteFlag = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("fraud_flags" as any)
        .delete()
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-fraud-flags"] });
      toast.success("Fraud flag removed");
    },
    onError: (err: any) => toast.error(err.message),
  });

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-black uppercase tracking-tight flex items-center gap-2">
            <ShieldAlert className="h-5 w-5 text-destructive" />
            Fraud Detection Center
          </h2>
          <p className="text-sm text-muted-foreground font-medium">
            Review suspicious activities and potential abuse.
          </p>
        </div>
        <Badge
          variant="destructive"
          className="rounded-xl px-4 py-1 font-black uppercase text-[10px] tracking-widest"
        >
          {flags?.filter((f: any) => f.status === "pending").length} Active Flags
        </Badge>
      </div>

      <div className="rounded-2xl border border-border/50 bg-card overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50">
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                User / Details
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Type
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Severity
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
            {flags?.length ? (
              flags.map((flag: any) => (
                <TableRow
                  key={flag.id}
                  className="border-border/40 hover:bg-accent/5 transition-colors"
                >
                  <TableCell className="px-6 py-4">
                    <div className="flex flex-col gap-1">
                      <div className="flex items-center gap-2 font-bold">
                        <User className="h-3 w-3 text-muted-foreground" />
                        {flag.profiles?.username || "Unknown"}
                      </div>
                      <div className="text-[10px] text-muted-foreground font-medium truncate max-w-[200px]">
                        {JSON.stringify(flag.details)}
                      </div>
                      <div className="text-[9px] text-muted-foreground/60 flex items-center gap-1 font-bold uppercase">
                        <Clock className="h-2.5 w-2.5" />
                        {format(new Date(flag.created_at), "MMM d, HH:mm")}
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <Badge
                      variant="outline"
                      className="rounded-lg text-[10px] font-black uppercase tracking-tighter border-muted-foreground/20"
                    >
                      {flag.type.replace("_", " ")}
                    </Badge>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-center">
                    <div className="flex justify-center">
                      {flag.severity === "high" ? (
                        <div className="flex items-center gap-1 text-destructive font-black text-[10px] uppercase">
                          <AlertTriangle className="h-3 w-3" />
                          Critical
                        </div>
                      ) : (
                        <div className="text-amber-600 font-black text-[10px] uppercase">
                          Medium
                        </div>
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-center">
                    <div className="flex justify-center">
                      <Badge
                        variant="secondary"
                        className={cn(
                          "rounded-lg text-[9px] font-black uppercase tracking-widest px-2 py-0.5",
                          flag.status === "pending" && "bg-amber-500/10 text-amber-600",
                          flag.status === "resolved" && "bg-emerald-500/10 text-emerald-600",
                          flag.status === "reviewed" && "bg-blue-500/10 text-blue-600",
                        )}
                      >
                        {flag.status}
                      </Badge>
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-right">
                    <div className="flex justify-end gap-2">
                      {flag.status === "pending" && (
                        <>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-emerald-600 hover:bg-emerald-500/10"
                            onClick={() =>
                              updateFlagStatus.mutate({ id: flag.id, status: "resolved" })
                            }
                          >
                            <CheckCircle2 className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-blue-600 hover:bg-blue-500/10"
                            onClick={() =>
                              updateFlagStatus.mutate({ id: flag.id, status: "reviewed" })
                            }
                          >
                            <Clock className="h-4 w-4" />
                          </Button>
                        </>
                      )}

                      <AlertDialog>
                        <AlertDialogTrigger asChild>
                          <Button
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-destructive hover:bg-destructive/10"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </AlertDialogTrigger>
                        <AlertDialogContent className="rounded-3xl border-none">
                          <AlertDialogHeader>
                            <AlertDialogTitle className="font-black uppercase tracking-tight">
                              Delete Fraud Flag?
                            </AlertDialogTitle>
                            <AlertDialogDescription className="font-medium text-muted-foreground">
                              This will remove the flag from the record. The user's account will
                              remain active.
                            </AlertDialogDescription>
                          </AlertDialogHeader>
                          <AlertDialogFooter>
                            <AlertDialogCancel className="rounded-xl font-bold">
                              Cancel
                            </AlertDialogCancel>
                            <AlertDialogAction
                              className="rounded-xl font-bold bg-destructive text-destructive-foreground"
                              onClick={() => deleteFlag.mutate(flag.id)}
                            >
                              Confirm Delete
                            </AlertDialogAction>
                          </AlertDialogFooter>
                        </AlertDialogContent>
                      </AlertDialog>
                    </div>
                  </TableCell>
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="h-32 text-center text-muted-foreground font-medium italic"
                >
                  No suspicious activity detected yet.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

function cn(...inputs: any[]) {
  return inputs.filter(Boolean).join(" ");
}
