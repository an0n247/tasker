import { useState, useEffect } from "react";
import { CheckCircle2, Clock, RefreshCcw, ExternalLink, Globe, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export function DomainStatusCard() {
  const [status, setStatus] = useState<"loading" | "pending" | "propagated" | "error">("loading");
  const [lastCheck, setLastCheck] = useState<Date | null>(null);
  const [progress, setProgress] = useState(0);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [refreshInterval] = useState(25); // default 25s

  const checkDns = async () => {
    setStatus("loading");
    setProgress(20);
    try {
      const res = await fetch("/api/public/dns-check?domain=noblegain.bytsphere.buzz");
      const data = await res.json();

      setProgress(100);
      const newStatus = data.status === "propagated" ? "propagated" : "pending";
      setStatus(newStatus);
      setLastCheck(new Date());

      if (newStatus === "propagated") {
        setAutoRefresh(false);
      }
    } catch (err) {
      console.error(err);
      setStatus("error");
    }
  };

  useEffect(() => {
    checkDns();
  }, []);

  useEffect(() => {
    if (!autoRefresh || status === "propagated") return;

    const timer = setInterval(() => {
      checkDns();
    }, refreshInterval * 1000);

    return () => clearInterval(timer);
  }, [autoRefresh, refreshInterval, status]);

  return (
    <Card className="border-border/40 bg-card/50 backdrop-blur-sm overflow-hidden">
      <div className={`h-1 w-full ${status === "propagated" ? "bg-green-500" : "bg-primary/20"}`}>
        <div
          className="h-full bg-primary transition-all duration-500"
          style={{ width: `${progress}%` }}
        />
      </div>

      <CardHeader className="pb-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Globe className="h-4 w-4 text-primary" />
            <CardTitle className="text-sm font-black uppercase tracking-tight">
              Domain Status
            </CardTitle>
          </div>
          <Badge
            variant={status === "propagated" ? "default" : "secondary"}
            className="rounded-lg uppercase font-black text-[9px] px-2 py-0 h-5"
          >
            {status}
          </Badge>
        </div>
        <CardDescription className="text-[10px] font-medium italic">
          Target: noblegain.bytsphere.buzz
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        <div className="flex items-center gap-3 p-3 rounded-xl bg-accent/5 border border-border/50">
          {status === "propagated" ? (
            <CheckCircle2 className="h-5 w-5 text-green-500 flex-shrink-0" />
          ) : status === "loading" ? (
            <RefreshCcw className="h-5 w-5 text-primary animate-spin flex-shrink-0" />
          ) : status === "error" ? (
            <AlertCircle className="h-5 w-5 text-destructive flex-shrink-0" />
          ) : (
            <Clock className="h-5 w-5 text-primary animate-pulse flex-shrink-0" />
          )}

          <div className="flex-1 min-w-0">
            <p className="font-black text-[10px] uppercase truncate">
              {status === "propagated" ? "Site Reachable" : "Propagation in Progress"}
            </p>
            <p className="text-[9px] text-muted-foreground font-medium leading-tight">
              {status === "propagated"
                ? "Your domain is correctly pointed."
                : "Waiting for global DNS update."}
            </p>
          </div>
        </div>

        <div className="flex gap-2">
          <Button
            onClick={checkDns}
            disabled={status === "loading"}
            size="sm"
            className="flex-1 rounded-lg font-black text-[10px] uppercase h-9 shadow-lg shadow-primary/20"
          >
            <RefreshCcw
              className={`mr-1.5 h-3 w-3 ${status === "loading" ? "animate-spin" : ""}`}
            />
            Check
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="flex-1 rounded-lg font-black text-[10px] uppercase h-9"
            asChild
          >
            <a
              href="https://whatsmydns.net/#CNAME/noblegain.bytsphere.buzz"
              target="_blank"
              rel="noopener noreferrer"
            >
              Global <ExternalLink className="ml-1 h-2 w-2" />
            </a>
          </Button>
        </div>

        {lastCheck && (
          <p className="text-[8px] text-center text-muted-foreground uppercase font-black tracking-widest">
            Last check: {lastCheck.toLocaleTimeString()}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
