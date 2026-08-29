import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
  AreaChart,
  Area,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import {
  Loader2,
  TrendingUp,
  UserPlus,
  Gift,
  ListTodo,
  RefreshCw,
  Calendar as CalendarIcon,
  Filter,
} from "lucide-react";
import { format, subDays, startOfDay, endOfDay } from "date-fns";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { DateRange } from "react-day-picker";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export function AnalyticsView() {
  const [date, setDate] = useState<DateRange | undefined>({
    from: subDays(new Date(), 30),
    to: new Date(),
  });
  const [selectedTaskId, setSelectedTaskId] = useState<string>("all");
  const [granularity, setGranularity] = useState<"day" | "week" | "month">("day");

  const { data: tasks } = useQuery({
    queryKey: ["admin-tasks-simple-analytics"],
    queryFn: async () => {
      const { data, error } = await supabase.from("tasks").select("id, title").order("title");
      if (error) throw error;
      return data as unknown as { id: string; title: string }[];
    },
  });

  const { data: analytics, isLoading: isLoadingFunnel } = useQuery({
    queryKey: ["funnelAnalytics", date?.from?.toISOString(), date?.to?.toISOString()],
    queryFn: async () => {
      const fromStr = date?.from
        ? startOfDay(date.from).toISOString()
        : subDays(new Date(), 30).toISOString();
      const toStr = date?.to ? endOfDay(date.to).toISOString() : new Date().toISOString();

      const { data, error } = await supabase.rpc("get_funnel_stats" as any, {
        start_date: fromStr,
        end_date: toStr,
      });
      if (error) throw error;

      const row = (Array.isArray(data) ? data[0] : data) as
        | { referrals: number; signups: number; bonuses: number }
        | undefined;

      const funnel = [
        {
          name: "Referrals",
          count: Number(row?.referrals ?? 0),
          icon: TrendingUp,
          color: "#8b5cf6",
        },
        {
          name: "Signup Complete",
          count: Number(row?.signups ?? 0),
          icon: UserPlus,
          color: "#10b981",
        },
        {
          name: "Welcome Bonus Claimed",
          count: Number(row?.bonuses ?? 0),
          icon: Gift,
          color: "#f59e0b",
        },
      ];


      return { funnel };
    },
  });

  const { data: economyData, isLoading: isLoadingEconomy } = useQuery({
    queryKey: [
      "economyAnalytics",
      date?.from?.toISOString(),
      date?.to?.toISOString(),
      selectedTaskId,
      granularity,
    ],
    queryFn: async () => {
      const fromStr = date?.from
        ? startOfDay(date.from).toISOString()
        : subDays(new Date(), 30).toISOString();
      const toStr = date?.to ? endOfDay(date.to).toISOString() : new Date().toISOString();
      const taskFilter = selectedTaskId === "all" ? {} : { filter_task_id: selectedTaskId };

      const [dailyRes, repeatableRes] = await Promise.all([
        supabase.rpc("get_daily_task_completions", {
          start_date: fromStr,
          end_date: toStr,
          granularity: granularity,
          ...taskFilter,
        }),
        supabase.rpc("get_repeatable_task_stats", {
          start_date: fromStr,
          end_date: toStr,
          ...taskFilter,
        }),
      ]);

      if (dailyRes.error) throw dailyRes.error;
      if (repeatableRes.error) throw repeatableRes.error;

      return {
        dailyCompletions: dailyRes.data || [],
        repeatableStats: repeatableRes.data || [],
      };
    },
  });

  const isLoading = isLoadingFunnel || isLoadingEconomy;

  return (
    <div className="space-y-6">
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <h3 className="text-xl font-black uppercase tracking-tight">Platform Analytics</h3>
          <p className="text-sm text-muted-foreground font-medium">
            Monitor user behavior and economy trends.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="flex bg-card/50 backdrop-blur-sm p-1 rounded-xl border border-border/40">
            {(["day", "week", "month"] as const).map((g) => (
              <button
                key={g}
                onClick={() => setGranularity(g)}
                className={cn(
                  "px-3 py-1.5 text-[10px] font-black uppercase tracking-widest rounded-lg transition-all",
                  granularity === g
                    ? "bg-primary text-primary-foreground shadow-lg shadow-primary/20"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                {g}
              </button>
            ))}
          </div>

          <div className="w-full sm:w-[200px]">
            <Select value={selectedTaskId} onValueChange={setSelectedTaskId}>
              <SelectTrigger className="rounded-xl border-border/40 bg-card/50 backdrop-blur-sm font-bold">
                <div className="flex items-center gap-2">
                  <Filter className="h-4 w-4 text-primary" />
                  <SelectValue placeholder="All Tasks" />
                </div>
              </SelectTrigger>
              <SelectContent className="rounded-2xl border-border/40">
                <SelectItem value="all" className="font-bold">
                  All Tasks
                </SelectItem>
                {tasks?.map((task) => (
                  <SelectItem key={task.id} value={task.id} className="font-bold">
                    {task.title}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant={"outline"}
                className={cn(
                  "w-full sm:w-[300px] justify-start text-left font-bold rounded-xl border-border/40 bg-card/50 backdrop-blur-sm",
                  !date && "text-muted-foreground",
                )}
              >
                <CalendarIcon className="mr-2 h-4 w-4 text-primary" />
                {date?.from ? (
                  date.to ? (
                    <>
                      {format(date.from, "LLL dd, y")} - {format(date.to, "LLL dd, y")}
                    </>
                  ) : (
                    format(date.from, "LLL dd, y")
                  )
                ) : (
                  <span>Pick a date range</span>
                )}
              </Button>
            </PopoverTrigger>
            <PopoverContent
              className="w-auto p-0 rounded-2xl border-border/40 shadow-2xl"
              align="end"
            >
              <Calendar
                initialFocus
                mode="range"
                defaultMonth={date?.from || new Date()}
                selected={date}
                onSelect={setDate}
                numberOfMonths={2}
              />
            </PopoverContent>
          </Popover>
        </div>
      </div>

      {isLoading ? (
        <div className="flex h-[400px] items-center justify-center">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
        </div>
      ) : (
        <>
          {/* Funnel Section */}
          <div className="grid gap-4 grid-cols-2 md:grid-cols-3">
            {analytics?.funnel.map((item) => (
              <Card
                key={item.name}
                className="border-border/40 bg-card/50 backdrop-blur-sm overflow-hidden group hover:border-primary/20 transition-all duration-300"
              >
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                    {item.name}
                  </CardTitle>
                  <item.icon className="h-4 w-4 text-primary" />
                </CardHeader>
                <CardContent>
                  <div className="text-3xl font-black tracking-tighter">{item.count}</div>
                </CardContent>
              </Card>
            ))}
          </div>

          <div className="grid gap-6 md:grid-cols-2">
            {/* Daily Tasks Chart */}
            <Card className="border-border/40 bg-card/50 backdrop-blur-sm p-6">
              <CardHeader className="px-0 pt-0">
                <div className="flex items-center gap-2 mb-1">
                  <ListTodo className="h-4 w-4 text-primary" />
                  <CardTitle className="text-xs font-black uppercase tracking-widest text-foreground">
                    Tasks Completed ({granularity})
                  </CardTitle>
                </div>
                <CardDescription className="text-[10px] font-bold uppercase tracking-tight">
                  {selectedTaskId === "all"
                    ? "Approved submissions in selected period"
                    : "Daily completions for selected task"}
                </CardDescription>
              </CardHeader>
              <CardContent className="px-0 pb-0 h-[300px]">
                {economyData?.dailyCompletions.length === 0 ? (
                  <div className="flex h-full items-center justify-center text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                    No data for this selection
                  </div>
                ) : (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={economyData?.dailyCompletions || []}>
                      <defs>
                        <linearGradient id="colorCount" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#8b5cf6" stopOpacity={0.3} />
                          <stop offset="95%" stopColor="#8b5cf6" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid
                        strokeDasharray="3 3"
                        vertical={false}
                        stroke="rgba(255,255,255,0.05)"
                      />
                      <XAxis
                        dataKey="completion_date"
                        tickFormatter={(str) => {
                          const d = new Date(str);
                          if (granularity === "month") return format(d, "MMM yyyy");
                          if (granularity === "week")
                            return `W${format(d, "w")} (${format(d, "MMM d")})`;
                          return format(d, "MMM d");
                        }}
                        tick={{ fontSize: 9, fontWeight: 800, fill: "var(--muted-foreground)" }}
                        axisLine={false}
                        tickLine={false}
                      />
                      <YAxis
                        tick={{ fontSize: 9, fontWeight: 800, fill: "var(--muted-foreground)" }}
                        axisLine={false}
                        tickLine={false}
                      />
                      <Tooltip
                        contentStyle={{
                          backgroundColor: "var(--card)",
                          border: "1px solid var(--border)",
                          borderRadius: "12px",
                          fontSize: "12px",
                          fontWeight: 800,
                        }}
                      />
                      <Area
                        type="monotone"
                        dataKey="count"
                        stroke="#8b5cf6"
                        fillOpacity={1}
                        fill="url(#colorCount)"
                        strokeWidth={3}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </CardContent>
            </Card>

            {/* Repeatable Tasks Chart */}
            <Card className="border-border/40 bg-card/50 backdrop-blur-sm p-6">
              <CardHeader className="px-0 pt-0">
                <div className="flex items-center gap-2 mb-1">
                  <RefreshCw className="h-4 w-4 text-primary" />
                  <CardTitle className="text-xs font-black uppercase tracking-widest text-foreground">
                    Repeatable Task Claim Rates
                  </CardTitle>
                </div>
                <CardDescription className="text-[10px] font-bold uppercase tracking-tight">
                  {selectedTaskId === "all"
                    ? "Avg claims per user in selected period"
                    : "Individual claim rate for selected task"}
                </CardDescription>
              </CardHeader>
              <CardContent className="px-0 pb-0 h-[300px]">
                {economyData?.repeatableStats.length === 0 ? (
                  <div className="flex h-full items-center justify-center text-[10px] font-black uppercase tracking-widest text-muted-foreground">
                    No data for this selection
                  </div>
                ) : (
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart
                      data={economyData?.repeatableStats || []}
                      layout="vertical"
                      margin={{ left: 20 }}
                    >
                      <CartesianGrid
                        strokeDasharray="3 3"
                        horizontal={false}
                        stroke="rgba(255,255,255,0.05)"
                      />
                      <XAxis type="number" tick={{ fontSize: 9, fontWeight: 800 }} hide />
                      <YAxis
                        dataKey="title"
                        type="category"
                        tick={{ fontSize: 8, fontWeight: 800, fill: "var(--muted-foreground)" }}
                        width={100}
                        axisLine={false}
                        tickLine={false}
                      />
                      <Tooltip
                        contentStyle={{
                          backgroundColor: "var(--card)",
                          border: "1px solid var(--border)",
                          borderRadius: "12px",
                          fontSize: "12px",
                          fontWeight: 800,
                        }}
                      />
                      <Bar
                        dataKey="claims_per_user"
                        fill="#10b981"
                        radius={[0, 4, 4, 0]}
                        barSize={20}
                      >
                        {economyData?.repeatableStats.map((entry: any, index: number) => (
                          <Cell
                            key={`cell-${index}`}
                            fill={index % 2 === 0 ? "#10b981" : "#34d399"}
                          />
                        ))}
                      </Bar>
                    </BarChart>
                  </ResponsiveContainer>
                )}
              </CardContent>
            </Card>
          </div>

          {/* Conversion Funnel Bar */}
          <Card className="border-border/40 bg-card/50 backdrop-blur-sm p-6">
            <CardHeader className="px-0 pt-0">
              <CardTitle className="text-xs font-black uppercase tracking-widest text-foreground">
                User Conversion Funnel
              </CardTitle>
            </CardHeader>
            <CardContent className="px-0 pb-0 h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={analytics?.funnel || []}
                  layout="vertical"
                  margin={{ left: 40, right: 40 }}
                >
                  <CartesianGrid
                    strokeDasharray="3 3"
                    horizontal={false}
                    stroke="rgba(255,255,255,0.05)"
                  />
                  <XAxis type="number" hide />
                  <YAxis
                    dataKey="name"
                    type="category"
                    scale="band"
                    axisLine={false}
                    tickLine={false}
                    tick={{ fontSize: 10, fontWeight: 800, fill: "var(--muted-foreground)" }}
                    width={150}
                  />
                  <Tooltip
                    cursor={{ fill: "rgba(255,255,255,0.02)" }}
                    contentStyle={{
                      backgroundColor: "var(--card)",
                      border: "1px solid var(--border)",
                      borderRadius: "12px",
                      fontSize: "12px",
                      fontWeight: 800,
                    }}
                  />
                  <Bar dataKey="count" radius={[0, 4, 4, 0]} barSize={40}>
                    {analytics?.funnel.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
