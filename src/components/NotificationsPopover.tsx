import { Bell } from "lucide-react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { formatDistanceToNow } from "date-fns";
import { toast } from "sonner";
import { useNavigate } from "@tanstack/react-router";
import { showTransactionDetails } from "@/utils/transaction-details";

export function NotificationsPopover() {
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const { data: notifications, isLoading } = useQuery({
    queryKey: ["notifications"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("notifications")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(20);
      if (error) throw error;
      return data;
    },
  });

  const markAsRead = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from("notifications").update({ is_read: true }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["notifications"] });
    },
  });

  const handleNotificationClick = async (notification: any) => {
    // Mark as read if not already read
    if (!notification.is_read) {
      markAsRead.mutate(notification.id);
    }

    // Priority 1: Deep links to referee details
    if (notification.metadata?.referee_id) {
      navigate({
        to: "/refer",
      });
      // Small delay to allow navigation to finish if needed, though refer page usually scrolls to bottom
      // or we can just navigate. In a real app we might pass a search param.
      return;
    }

    // Priority 2: Transaction specific details
    if (notification.transaction_id) {
      navigate({
        to: "/transactions",
        search: { transactionId: notification.transaction_id },
      });
    }
    // Priority 3: General navigation
    else if (notification.type === "points" || notification.type === "reward") {
      navigate({ to: "/transactions" });
    }
  };

  const unreadCount = notifications?.filter((n) => !n.is_read).length || 0;

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button variant="ghost" size="icon" className="relative" aria-label="Notifications">
          <Bell className="h-5 w-5" />
          {unreadCount > 0 && (
            <Badge
              variant="destructive"
              className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center p-0 text-[10px]"
            >
              {unreadCount}
            </Badge>
          )}
        </Button>
      </PopoverTrigger>
      <PopoverContent className="w-80 p-0" align="end">
        <div className="flex items-center justify-between p-4 border-b">
          <h4 className="font-semibold text-sm">Notifications</h4>
          {unreadCount > 0 && (
            <Button
              variant="ghost"
              size="sm"
              className="text-xs h-auto p-0"
              onClick={async () => {
                const unreadIds = notifications?.filter((n) => !n.is_read).map((n) => n.id) || [];
                for (const id of unreadIds) {
                  await markAsRead.mutateAsync(id);
                }
                toast.success("All caught up!");
              }}
            >
              Mark all as read
            </Button>
          )}
        </div>
        <ScrollArea className="h-[300px]">
          {isLoading ? (
            <div className="p-4 text-center text-sm text-muted-foreground">Loading...</div>
          ) : notifications?.length === 0 ? (
            <div className="p-4 text-center text-sm text-muted-foreground">
              No notifications yet.
            </div>
          ) : (
            <div className="divide-y">
              {notifications?.map((notification) => (
                <div
                  key={notification.id}
                  className={`p-4 transition-colors hover:bg-muted/50 cursor-pointer ${!notification.is_read ? "bg-primary/5" : ""}`}
                  onClick={() => handleNotificationClick(notification)}
                >
                  <p className="text-sm font-medium">{notification.title || "Notification"}</p>
                  <p className="text-xs text-muted-foreground mt-1">{notification.message}</p>
                  <p className="text-[10px] text-muted-foreground mt-2">
                    {formatDistanceToNow(new Date(notification.created_at), { addSuffix: true })}
                  </p>
                </div>
              ))}
            </div>
          )}
        </ScrollArea>
      </PopoverContent>
    </Popover>
  );
}
