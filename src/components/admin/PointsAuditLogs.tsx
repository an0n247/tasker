import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
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
import {
  Loader2,
  Coins,
  User,
  Activity,
  ChevronUp,
  ChevronDown,
  ArrowUpDown,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export function PointsAuditLogs() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [pageSize] = useState(10);
  const [sortField, setSortField] = useState<string>("created_at");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("desc");

  const { data, isLoading } = useQuery({
    queryKey: ["admin-points-audit-logs", page, sortField, sortDirection],
    queryFn: async () => {
      const from = (page - 1) * pageSize;
      const to = from + pageSize - 1;

      let query = supabase.from("points_audit_logs").select(
        `
          *,
          profiles:user_id (
            username,
            full_name
          )
        `,
        { count: "exact" },
      );

      // Handle sorting
      if (sortField === "username") {
        // PostgREST doesn't support sorting by related table columns directly easily in a single call without specialized views
        // But we can try to order by the foreign key relation if supported or just stick to local columns for now.
        // For now, we'll sort by local columns and if it's username we'll default to created_at
        query = query.order("created_at", { ascending: sortDirection === "asc" });
      } else {
        query = query.order(sortField, { ascending: sortDirection === "asc" });
      }

      const { data, error, count } = await query.range(from, to);

      if (error) throw error;
      return { logs: data, totalCount: count || 0 };
    },
  });

  const toggleSort = (field: string) => {
    if (sortField === field) {
      setSortDirection(sortDirection === "asc" ? "desc" : "asc");
    } else {
      setSortField(field);
      setSortDirection("desc");
    }
    setPage(1); // Reset to first page on sort change
  };

  const logs = data?.logs || [];
  const totalCount = data?.totalCount || 0;
  const totalPages = Math.ceil(totalCount / pageSize);

  useEffect(() => {
    const channel = supabase
      .channel("points-audit-realtime")
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "public",
          table: "points_audit_logs",
        },
        () => {
          queryClient.invalidateQueries({ queryKey: ["admin-points-audit-logs"] });
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [queryClient]);

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );

  return (
    <div className="space-y-4 animate-in fade-in duration-500">
      <div>
        <h3 className="text-xl font-black uppercase tracking-tight">Points Audit Logs</h3>
        <p className="text-sm text-muted-foreground font-medium">
          Detailed history of every point credit including welcome and referral rewards.
        </p>
      </div>

      <div className="rounded-2xl border border-border/50 bg-card/50 backdrop-blur-sm overflow-hidden overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50">
              <TableHead
                className="font-black uppercase text-[10px] tracking-widest px-6 cursor-pointer hover:text-primary transition-colors"
                onClick={() => toggleSort("username")}
              >
                <div className="flex items-center gap-1">
                  User
                  {sortField === "username" ? (
                    sortDirection === "asc" ? (
                      <ChevronUp className="h-3 w-3" />
                    ) : (
                      <ChevronDown className="h-3 w-3" />
                    )
                  ) : (
                    <ArrowUpDown className="h-2.5 w-2.5 opacity-50" />
                  )}
                </div>
              </TableHead>
              <TableHead
                className="font-black uppercase text-[10px] tracking-widest px-6 cursor-pointer hover:text-primary transition-colors"
                onClick={() => toggleSort("amount")}
              >
                <div className="flex items-center gap-1">
                  Amount
                  {sortField === "amount" ? (
                    sortDirection === "asc" ? (
                      <ChevronUp className="h-3 w-3" />
                    ) : (
                      <ChevronDown className="h-3 w-3" />
                    )
                  ) : (
                    <ArrowUpDown className="h-2.5 w-2.5 opacity-50" />
                  )}
                </div>
              </TableHead>
              <TableHead
                className="font-black uppercase text-[10px] tracking-widest px-6 cursor-pointer hover:text-primary transition-colors"
                onClick={() => toggleSort("reason")}
              >
                <div className="flex items-center gap-1">
                  Reason
                  {sortField === "reason" ? (
                    sortDirection === "asc" ? (
                      <ChevronUp className="h-3 w-3" />
                    ) : (
                      <ChevronDown className="h-3 w-3" />
                    )
                  ) : (
                    <ArrowUpDown className="h-2.5 w-2.5 opacity-50" />
                  )}
                </div>
              </TableHead>
              <TableHead
                className="font-black uppercase text-[10px] tracking-widest px-6 cursor-pointer hover:text-primary transition-colors"
                onClick={() => toggleSort("trigger_name")}
              >
                <div className="flex items-center gap-1">
                  Source
                  {sortField === "trigger_name" ? (
                    sortDirection === "asc" ? (
                      <ChevronUp className="h-3 w-3" />
                    ) : (
                      <ChevronDown className="h-3 w-3" />
                    )
                  ) : (
                    <ArrowUpDown className="h-2.5 w-2.5 opacity-50" />
                  )}
                </div>
              </TableHead>
              <TableHead
                className="font-black uppercase text-[10px] tracking-widest px-6 text-right cursor-pointer hover:text-primary transition-colors"
                onClick={() => toggleSort("created_at")}
              >
                <div className="flex items-center justify-end gap-1">
                  Timestamp
                  {sortField === "created_at" ? (
                    sortDirection === "asc" ? (
                      <ChevronUp className="h-3 w-3" />
                    ) : (
                      <ChevronDown className="h-3 w-3" />
                    )
                  ) : (
                    <ArrowUpDown className="h-2.5 w-2.5 opacity-50" />
                  )}
                </div>
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
                  No point audit logs recorded yet.
                </TableCell>
              </TableRow>
            ) : (
              logs?.map((log: any) => (
                <TableRow
                  key={log.id}
                  className="border-border/40 hover:bg-accent/5 transition-colors group"
                >
                  <TableCell className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <div className="bg-primary/5 p-1.5 rounded-lg group-hover:bg-primary/10 transition-colors">
                        <User className="h-3 w-3 text-primary" />
                      </div>
                      <div>
                        <div className="font-bold text-sm tracking-tight">
                          {log.profiles?.username || "Unknown"}
                        </div>
                        <div className="text-[10px] text-muted-foreground font-medium">
                          {log.profiles?.full_name}
                        </div>
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <div className="flex items-center gap-1.5">
                      <div className="bg-green-500/10 p-1.5 rounded-lg">
                        <Coins className="h-3.3 w-3.3 text-green-600" />
                      </div>
                      <span className="font-black text-green-600 text-sm">+{log.amount}</span>
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <Badge
                      variant="outline"
                      className="font-black uppercase text-[9px] tracking-wider px-2 py-0.5 border-primary/20 bg-primary/5 text-primary"
                    >
                      {log.reason}
                    </Badge>
                  </TableCell>
                  <TableCell className="px-6 py-4">
                    <div className="flex items-center gap-1.5">
                      <Activity className="h-3 w-3 text-muted-foreground" />
                      <span className="text-[10px] font-mono text-muted-foreground bg-muted/30 px-1.5 py-0.5 rounded uppercase">
                        {log.trigger_name}
                      </span>
                    </div>
                  </TableCell>
                  <TableCell className="px-6 py-4 text-right">
                    <div className="text-[10px] font-black text-muted-foreground uppercase tracking-widest">
                      {format(new Date(log.created_at), "MMM d, yyyy")}
                    </div>
                    <div className="text-[9px] text-muted-foreground/60 font-bold">
                      {format(new Date(log.created_at), "HH:mm:ss")}
                    </div>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between px-2 py-4">
          <div className="text-xs text-muted-foreground font-medium">
            Showing <span className="font-bold text-foreground">{(page - 1) * pageSize + 1}</span>{" "}
            to{" "}
            <span className="font-bold text-foreground">
              {Math.min(page * pageSize, totalCount)}
            </span>{" "}
            of <span className="font-bold text-foreground">{totalCount}</span> logs
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="h-8 px-2 min-w-[80px] font-black uppercase text-[10px] tracking-widest"
            >
              <ChevronLeft className="h-4 w-4 mr-1" />
              Previous
            </Button>
            <div className="flex items-center gap-1">
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                let pageNum;
                if (totalPages <= 5) {
                  pageNum = i + 1;
                } else if (page <= 3) {
                  pageNum = i + 1;
                } else if (page >= totalPages - 2) {
                  pageNum = totalPages - 4 + i;
                } else {
                  pageNum = page - 2 + i;
                }

                return (
                  <Button
                    key={pageNum}
                    variant={page === pageNum ? "default" : "outline"}
                    size="sm"
                    onClick={() => setPage(pageNum)}
                    className={cn(
                      "h-8 w-8 p-0 font-bold text-[10px]",
                      page === pageNum ? "bg-primary" : "hover:bg-primary/10 hover:text-primary",
                    )}
                  >
                    {pageNum}
                  </Button>
                );
              })}
            </div>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="h-8 px-2 min-w-[80px] font-black uppercase text-[10px] tracking-widest"
            >
              Next
              <ChevronRight className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
