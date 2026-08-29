import { useQuery } from "@tanstack/react-query";
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
import { Loader2, History, Database, ArrowRight } from "lucide-react";
import { format } from "date-fns";

export function AuditLogs() {
  const { data: logs, isLoading } = useQuery({
    queryKey: ["admin-audit-logs"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("admin_audit_logs" as any)
        .select(
          `
          *,
          profiles:admin_id (
            username,
            full_name
          )
        `,
        )
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data;
    },
  });

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-xl font-black uppercase tracking-tight">Admin Audit Logs</h3>
        <p className="text-sm text-muted-foreground font-medium">
          History of all changes to tasks and rewards.
        </p>
      </div>

      <div className="rounded-2xl border border-border/50 bg-card overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50">
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Admin
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Action
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Target
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6">
                Details
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-right">
                Date
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {logs?.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={5}
                  className="text-center py-12 text-muted-foreground font-medium"
                >
                  No audit logs found.
                </TableCell>
              </TableRow>
            ) : (
              logs?.map((log: any) => (
                <TableRow
                  key={log.id}
                  className="border-border/40 hover:bg-accent/5 transition-colors"
                >
                  <TableCell className="px-6 py-4">
                    <div className="font-bold">{log.profiles?.username || "System"}</div>
                    <div className="text-[10px] text-muted-foreground">
                      {log.profiles?.full_name}
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <Badge
                      className={cn(
                        "font-black uppercase text-[10px] tracking-wider px-2 py-0.5",
                        log.action_type === "INSERT" && "bg-green-500/10 text-green-600",
                        log.action_type === "UPDATE" && "bg-blue-500/10 text-blue-600",
                        log.action_type === "DELETE" && "bg-destructive/10 text-destructive",
                      )}
                    >
                      {log.action_type}
                    </Badge>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <div className="flex items-center gap-1.5 font-bold">
                      <Database className="h-3 w-3 text-muted-foreground" />
                      {log.target_table}
                    </div>
                    <div className="text-[10px] text-muted-foreground font-mono">
                      {log.target_id.slice(0, 8)}...
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <div className="text-xs max-w-[300px]">
                      {log.action_type === "UPDATE" ? (
                        <div className="flex flex-col gap-1">
                          {Object.keys(log.new_data || {}).map((key) => {
                            if (
                              JSON.stringify(log.old_data?.[key]) !==
                              JSON.stringify(log.new_data?.[key])
                            ) {
                              return (
                                <div key={key} className="flex items-center gap-1 flex-wrap">
                                  <span className="font-bold text-[10px] uppercase text-muted-foreground">
                                    {key}:
                                  </span>
                                  <span className="text-destructive line-through decoration-1">
                                    {String(log.old_data?.[key]).slice(0, 20)}
                                  </span>
                                  <ArrowRight className="h-2 w-2 text-muted-foreground" />
                                  <span className="text-green-600 font-medium">
                                    {String(log.new_data?.[key]).slice(0, 20)}
                                  </span>
                                </div>
                              );
                            }
                            return null;
                          })}
                        </div>
                      ) : (
                        <div className="text-muted-foreground italic text-[10px]">
                          {log.action_type === "INSERT" ? "Created new entry" : "Deleted entry"}
                        </div>
                      )}
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-right">
                    <div className="text-[10px] font-bold text-muted-foreground uppercase tracking-wider">
                      {format(new Date(log.created_at), "MMM d, yyyy")}
                    </div>
                    <div className="text-[9px] text-muted-foreground/60">
                      {format(new Date(log.created_at), "HH:mm:ss")}
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}

function cn(...classes: any[]) {
  return classes.filter(Boolean).join(" ");
}
