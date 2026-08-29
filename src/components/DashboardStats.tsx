import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { TrendingUp, Clock, Share2, Award } from "lucide-react";

export function DashboardStats() {
  const { data: streak } = useQuery({
    queryKey: ["streak"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return null;
      const { data } = await supabase
        .from("user_streaks")
        .select("*")
        .eq("user_id", user.id)
        .single();
      return data;
    },
  });

  const { data: referralCount } = useQuery({
    queryKey: ["referralCount"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return 0;
      const { count } = await supabase
        .from("referrals")
        .select("*", { count: "exact", head: true })
        .eq("referrer_id", user.id);
      return count || 0;
    },
  });

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      <Card className="bg-primary text-primary-foreground">
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Total Balance</CardTitle>
          <TrendingUp className="h-4 w-4 opacity-70" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">Points</div>
          <p className="text-xs opacity-70">Keep earning!</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Active Referrals</CardTitle>
          <Share2 className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{referralCount}</div>
          <p className="text-xs text-muted-foreground">Successful invites</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Daily Streak</CardTitle>
          <Clock className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">{streak?.current_streak || 0} Days</div>
          <p className="text-xs text-muted-foreground">Longest: {streak?.longest_streak || 0}</p>
        </CardContent>
      </Card>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
          <CardTitle className="text-sm font-medium">Current Rank</CardTitle>
          <Award className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          <div className="text-2xl font-bold">Newbie</div>
          <p className="text-xs text-muted-foreground">Level 1</p>
        </CardContent>
      </Card>
    </div>
  );
}
