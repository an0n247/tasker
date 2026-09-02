import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Coins,
  CheckCircle2,
  Star,
  Twitter,
  Clock,
  ShieldCheck,
  Loader2,
  Play,
  CheckCircle,
  XCircle,
  ArrowRight,
  Flame,
  Target,
  ExternalLink,
  ChevronRight,
  AlertTriangle,
  Layers,
  Filter,
  KeyRound,
  HelpCircle,
  ListTodo,
  Info,
  Sparkles,
  Calendar,
} from "lucide-react";
import VastAdModal from "@/components/VastAdModal";
import { toast } from "sonner";
import confetti from "canvas-confetti";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { cn } from "@/lib/utils";
import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { parseTaskKeywordData } from "@/components/admin/TasksManager";
import { useAuth } from "@/hooks/use-auth";

export const Route = createFileRoute("/_authenticated/earn")({
  head: () => ({
    title: "Earn Tasks | Tasks, Blogs, Ads & Surveys | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Complete tasks, read blog posts, watch video ads, and participate in surveys to earn reward points on Noble Gain.",
      },
      { property: "og:title", content: "Earn Points | Tasks, Blogs & Rewards | Noble Gain" },
      {
        property: "og:description",
        content: "Complete daily verified tasks and watch your points grow in real-time.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: EarnPage,
});

const fadeInUp = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.45, ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number] },
  },
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.06 },
  },
};

// Seeded PRNG (Mulberry32) for deterministic daily randomization per user
function seededShuffle<T>(array: T[], seed: number): T[] {
  const arr = [...array];
  let s = seed;
  for (let i = arr.length - 1; i > 0; i--) {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    const rand = ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    const j = Math.floor(rand * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function EarnPage() {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [activeStatus, setActiveStatus] = useState<
    "available" | "in_progress" | "completed" | "rejected"
  >("available");
  const [completingTaskId, setCompletingTaskId] = useState<string | null>(null);
  const [taskUiStates, setTaskUiStates] = useState<
    Record<string, "idle" | "verifying" | "awaiting_confirmation" | "submitting">
  >({});
  const [activeVastTask, setActiveVastTask] = useState<any | null>(null);

  // Instruction Modal State
  const [instructionModalTask, setInstructionModalTask] = useState<any | null>(null);

  // Keyword Modal State
  const [keywordModalTask, setKeywordModalTask] = useState<any | null>(null);
  const [keywordInput, setKeywordInput] = useState("");
  const [keywordError, setKeywordError] = useState(false);
  const [submittingKeyword, setSubmittingKeyword] = useState(false);

  const {
    data: tasks,
    isLoading,
    refetch: refetchTasks,
  } = useQuery({
    queryKey: ["tasks", user?.id],
    queryFn: async () => {
      const {
        data: { user: authUser },
      } = await supabase.auth.getUser();
      if (!authUser) return [];

      const { data: tasksData } = await supabase
        .from("tasks" as any)
        .select("*, is_repeatable")
        .eq("is_active", true)
        .order("created_at", { ascending: false });
      const { data: submissions } = await supabase
        .from("task_submissions" as any)
        .select("task_id, status, admin_note, created_at")
        .eq("user_id", authUser.id);
      const { data: videoProgress } = await supabase
        .from("video_ad_progress")
        .select("task_id, watch_count")
        .eq("user_id", authUser.id);

      const submissionsMap = new Map(
        (submissions as any)?.map((s: any) => [
          s.task_id,
          { status: s.status, admin_note: s.admin_note, created_at: s.created_at },
        ]),
      );
      const progressMap = new Map(
        (videoProgress as any)?.map((p: any) => [p.task_id, p.watch_count]),
      );

      return (
        (tasksData as any)?.map((task: any) => {
          const submission = submissionsMap.get(task.id) as
            { status: string; admin_note: string; created_at: string } | undefined;
          return {
            ...task,
            status: submission?.status || null,
            admin_note: submission?.admin_note || null,
            submission_date: submission?.created_at || null,
            watch_count: progressMap.get(task.id) || 0,
          };
        }) || []
      );
    },
  });

  const { data: dailyStats } = useQuery({
    queryKey: ["daily-task-stats", user?.id],
    queryFn: async () => {
      const {
        data: { user: authUser },
      } = await supabase.auth.getUser();
      if (!authUser) return { daily_count: 0 };

      const { data, error } = await supabase
        .from("user_daily_task_counts" as any)
        .select("*")
        .eq("user_id", authUser.id)
        .maybeSingle();

      if (error) console.error("Error fetching daily stats:", error);
      return (data as any) || { daily_count: 0 };
    },
  });

  const dailyCount = dailyStats?.daily_count || 0;
  const dailyLimit = 10;
  const remainingDaily = Math.max(0, dailyLimit - dailyCount);
  const dailyLimitReached = dailyCount >= dailyLimit;

  // Compute stable daily user seed
  const dailyUserSeed = useMemo(() => {
    const todayStr = new Date().toISOString().split("T")[0];
    const combined = `${todayStr}_${user?.id || "guest_user"}`;
    let hash = 0;
    for (let i = 0; i < combined.length; i++) {
      hash = (hash << 5) - hash + combined.charCodeAt(i);
      hash |= 0;
    }
    return Math.abs(hash);
  }, [user?.id]);

  const { data: socialCheck } = useQuery({
    queryKey: ["social-verification", user?.id],
    queryFn: async () => {
      const {
        data: { user: authUser },
      } = await supabase.auth.getUser();
      if (!authUser) return { complete: false, missing: [] as string[] };

      const { data: profile } = await supabase
        .from("profiles")
        .select("twitter_handle, telegram_handle, instagram_handle, facebook_handle")
        .eq("id", authUser.id)
        .single();

      const { data: settings } = await (supabase.from("app_settings" as any) as any)
        .select("value")
        .eq("key", "welcome_bonus_required_socials")
        .single();

      const required = (settings?.value as string[]) || [];
      const missing = required.filter((social: string) => {
        const val = (profile as any)?.[`${social}_handle`];
        return !val || !String(val).trim();
      });

      return { complete: missing.length === 0, missing };
    },
    refetchOnMount: "always",
    refetchOnWindowFocus: true,
    staleTime: 0,
  });

  const socialLocked = socialCheck ? !socialCheck.complete : false;

  // Process categorized and randomized daily tasks
  const { availableDailyPool, inProgressTasks, completedTasks, rejectedTasks } = useMemo(() => {
    if (!tasks || !Array.isArray(tasks)) {
      return { availableDailyPool: [], inProgressTasks: [], completedTasks: [], rejectedTasks: [] };
    }

    const todayStr = new Date().toISOString().split("T")[0];

    const inProg: any[] = [];
    const comp: any[] = [];
    const rej: any[] = [];
    const candidates: any[] = [];

    for (const t of tasks as any[]) {
      const isVerifiedToday =
        t.status === "verified" &&
        t.submission_date &&
        new Date(t.submission_date).toISOString().split("T")[0] === todayStr;
      const isCompletedNonRepeatable = t.status === "verified" && !t.is_repeatable;
      const isPending = t.status === "pending";
      const isRejected = t.status === "rejected";

      if (isVerifiedToday || isCompletedNonRepeatable) {
        comp.push(t);
      } else if (isPending) {
        inProg.push(t);
      } else if (isRejected) {
        rej.push(t);
      } else {
        candidates.push(t);
      }
    }

    // Deterministically randomize candidate tasks per user for today
    const randomized = seededShuffle(candidates, dailyUserSeed);

    // Select the user's daily 10 allocation
    const daily10Tasks = randomized.slice(0, 10);

    return {
      availableDailyPool: daily10Tasks,
      inProgressTasks: inProg,
      completedTasks: comp,
      rejectedTasks: rej,
    };
  }, [tasks, dailyUserSeed]);

  // Tasks to display based on active status tab
  const displayTasks = useMemo(() => {
    if (activeStatus === "completed") return completedTasks;
    if (activeStatus === "in_progress") return inProgressTasks;
    if (activeStatus === "rejected") return rejectedTasks;

    // Available tab: capped to remaining daily allowance (10 max)
    if (dailyLimitReached) return [];
    return availableDailyPool.slice(0, remainingDaily);
  }, [
    activeStatus,
    availableDailyPool,
    inProgressTasks,
    completedTasks,
    rejectedTasks,
    dailyLimitReached,
    remainingDaily,
  ]);

  const availableCount = dailyLimitReached
    ? 0
    : Math.min(remainingDaily, availableDailyPool.length);
  const inProgressCount = inProgressTasks.length;
  const completedCount = completedTasks.length;

  const handleStartTaskExecution = (task: any) => {
    setInstructionModalTask(null);

    const taskAny = task as any;
    if (taskAny.link_url) {
      window.open(taskAny.link_url, "_blank");
    }

    setTaskUiStates((prev) => ({ ...prev, [task.id]: "verifying" }));

    // Wait 4 seconds before allowing confirmation
    setTimeout(() => {
      setTaskUiStates((prev) => ({ ...prev, [task.id]: "awaiting_confirmation" }));
    }, 4000);
  };

  const handleVerifyKeywordSubmit = async () => {
    if (!keywordModalTask) return;
    const parsed = parseTaskKeywordData(keywordModalTask.icon_name);
    const expectedKeyword = parsed.keyword.trim().toLowerCase();
    const entered = keywordInput.trim().toLowerCase();

    if (!entered) {
      toast.error("Please enter the keyword found in the blog or task.");
      return;
    }

    if (entered !== expectedKeyword) {
      setKeywordError(true);
      toast.error(
        "Incorrect keyword! Please check the blog article or task instructions carefully.",
      );
      return;
    }

    // Correct Keyword Match!
    setSubmittingKeyword(true);
    try {
      const {
        data: { user: authUser },
      } = await supabase.auth.getUser();
      if (!authUser) throw new Error("Not authenticated");

      const { data, error } = await (supabase.rpc as any)("submit_task", {
        _user_id: authUser.id,
        _task_id: keywordModalTask.id,
      });

      if (error) throw error;
      if (data && !(data as any).success) {
        throw new Error((data as any).message);
      }

      confetti({
        particleCount: 80,
        spread: 60,
        origin: { y: 0.6 },
      });

      toast.success(
        (data as any)?.message || `Task verified! +${keywordModalTask.points} Points added.`,
      );
      setKeywordModalTask(null);
      setTaskUiStates((prev) => ({ ...prev, [keywordModalTask.id]: "idle" }));
      refetchTasks();
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
    } catch (err: any) {
      toast.error(err.message || "Failed to submit task");
    } finally {
      setSubmittingKeyword(false);
    }
  };

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-7xl mx-auto pb-12"
    >
      {/* Background ambient light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header Banner */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Target className="size-3.5" />
            <span>Task Hub</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Daily Verified Tasks</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Earn <span className="text-gold">Points</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Complete your daily partner tasks, articles, likes, and comments to earn rewards.
          </p>
        </div>

        {/* Daily Allowance Tracker Card */}
        <div className="rounded-2xl border border-hairline bg-ink-2/70 p-4 min-w-[260px] shadow-sm backdrop-blur-md">
          <div className="flex items-center justify-between gap-2 mb-2">
            <span className="text-xs font-bold text-ink-muted uppercase tracking-wider flex items-center gap-1.5">
              <Flame className="size-4 text-amber-500 fill-amber-500" />
              Daily Quota
            </span>
            <span className="text-xs font-black font-mono text-ink-fg">
              {dailyCount} <span className="text-ink-muted">/ {dailyLimit} Tasks Done</span>
            </span>
          </div>
          <div className="h-2 bg-ink-3 rounded-full overflow-hidden border border-hairline">
            <div
              style={{ width: `${Math.min(100, (dailyCount / dailyLimit) * 100)}%` }}
              className={cn(
                "h-full rounded-full transition-all duration-500",
                dailyLimitReached ? "bg-amber-500" : "bg-gradient-to-r from-gold to-emerald-400",
              )}
            />
          </div>
          <p className="text-[11px] font-medium text-ink-muted mt-2 text-right">
            {dailyLimitReached ? (
              <span className="text-amber-500 font-bold">10 / 10 limit reached for today</span>
            ) : (
              <span>
                <strong>{remainingDaily}</strong> daily {remainingDaily === 1 ? "task" : "tasks"}{" "}
                remaining
              </span>
            )}
          </p>
        </div>
      </motion.header>

      {/* Social Profile Lock Alert */}
      {socialLocked && (
        <motion.div
          variants={fadeInUp}
          className="rounded-2xl border border-amber-500/30 bg-amber-500/10 p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 text-ink-fg shadow-sm"
        >
          <div className="flex items-start gap-3.5">
            <div className="size-10 rounded-xl bg-amber-500/20 text-amber-500 flex items-center justify-center shrink-0 mt-0.5 border border-amber-500/30">
              <ShieldCheck className="size-5" />
            </div>
            <div>
              <p className="font-bold text-sm text-ink-fg">
                Complete your social profile to unlock tasks
              </p>
              <p className="text-xs text-ink-muted mt-0.5 font-medium">
                Add your required social handles ({socialCheck?.missing.join(", ")}) in your profile
                to start earning points.
              </p>
            </div>
          </div>
          <Button
            asChild
            className="rounded-xl font-bold h-10 px-5 text-xs bg-gold text-ink hover:bg-gold-soft shrink-0 shadow-md"
          >
            <Link to="/profile">
              Complete Profile
              <ArrowRight className="size-3.5 ml-1.5" />
            </Link>
          </Button>
        </motion.div>
      )}

      {/* Navigation Filter Controls */}
      <motion.div variants={fadeInUp} className="space-y-4">
        <div className="flex flex-col lg:flex-row gap-4 lg:items-center justify-between">
          {/* Status Tabs */}
          <div className="flex p-1.5 bg-ink-2/80 rounded-2xl border border-hairline shadow-sm w-fit max-w-full overflow-x-auto scrollbar-none">
            <button
              type="button"
              onClick={() => setActiveStatus("available")}
              className={cn(
                "px-4 sm:px-5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
                activeStatus === "available"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <span>Available</span>
              <span
                className={cn(
                  "px-1.5 py-0.2 rounded-md text-[10px] font-mono",
                  activeStatus === "available" ? "bg-ink/15 text-ink" : "bg-ink-3 text-ink-muted",
                )}
              >
                {availableCount}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setActiveStatus("in_progress")}
              className={cn(
                "px-4 sm:px-5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
                activeStatus === "in_progress"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <span>Verifying</span>
              {inProgressCount > 0 && (
                <span
                  className={cn(
                    "px-1.5 py-0.2 rounded-md text-[10px] font-mono",
                    activeStatus === "in_progress"
                      ? "bg-ink/15 text-ink"
                      : "bg-amber-500/20 text-amber-400",
                  )}
                >
                  {inProgressCount}
                </span>
              )}
            </button>

            <button
              type="button"
              onClick={() => setActiveStatus("completed")}
              className={cn(
                "px-4 sm:px-5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer flex items-center gap-1.5",
                activeStatus === "completed"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <span>Completed</span>
              <span
                className={cn(
                  "px-1.5 py-0.2 rounded-md text-[10px] font-mono",
                  activeStatus === "completed" ? "bg-ink/15 text-ink" : "bg-ink-3 text-ink-muted",
                )}
              >
                {completedCount}
              </span>
            </button>

            <button
              type="button"
              onClick={() => setActiveStatus("rejected")}
              className={cn(
                "px-4 sm:px-5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap cursor-pointer",
                activeStatus === "rejected"
                  ? "bg-gold text-ink shadow-md font-black"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              Rejected
            </button>
          </div>

          <div className="flex items-center gap-2 text-xs text-ink-muted">
            <Sparkles className="size-4 text-gold shrink-0" />
            <span>Fresh tasks refreshed for you daily.</span>
          </div>
        </div>
      </motion.div>

      {/* Daily Limit Reached Alert on Available tab */}
      {activeStatus === "available" && dailyLimitReached && (
        <motion.div
          variants={fadeInUp}
          className="rounded-3xl border border-amber-500/30 bg-amber-500/10 p-8 text-center space-y-3 backdrop-blur-xl"
        >
          <div className="size-14 rounded-2xl bg-amber-500/20 text-amber-400 flex items-center justify-center mx-auto border border-amber-500/30">
            <CheckCircle2 className="size-7" />
          </div>
          <div className="space-y-1 max-w-md mx-auto">
            <h3 className="text-lg font-black text-ink-fg">
              Daily Limit Completed ({dailyCount}/{dailyLimit} Tasks)
            </h3>
            <p className="text-xs text-ink-muted leading-relaxed font-medium">
              You have completed your 10 tasks for today! Awesome work. Check back tomorrow for your
              next batch of daily tasks.
            </p>
          </div>
          <Button
            onClick={() => setActiveStatus("completed")}
            className="rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft px-5 cursor-pointer shadow-md"
          >
            View Completed Tasks
          </Button>
        </motion.div>
      )}

      {/* Task Cards Grid */}
      {(!dailyLimitReached || activeStatus !== "available") && (
        <motion.div
          variants={fadeInUp}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {displayTasks?.length
            ? (displayTasks as any[]).map((task: any) => {
                const isPending = task.status === "pending";
                const isVerified = task.status === "verified";
                const isRejected = task.status === "rejected";
                const isVideo = task.category === "Videos" && task.video_ad_count > 0;
                const parsedKeyword = parseTaskKeywordData(task.icon_name);
                const hasKeyword = parsedKeyword.hasKeyword;
                const currentUi = taskUiStates[task.id] || "idle";
                const isSubmitting = currentUi === "submitting" || completingTaskId === task.id;

                return (
                  <div
                    key={task.id}
                    className="rounded-3xl p-6 bg-ink-2/70 border border-hairline shadow-lg flex flex-col justify-between relative overflow-hidden group hover:border-gold/30 transition-all duration-300 backdrop-blur-xl"
                  >
                    {/* Subtle card top accent line */}
                    <div className="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-transparent via-gold/30 to-transparent group-hover:via-gold transition-all" />

                    <div className="space-y-4">
                      {/* Header Badge Row */}
                      <div className="flex justify-between items-start gap-2">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="inline-flex items-center gap-1 rounded-lg border border-hairline bg-ink-3 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-ink-fg">
                            {task.category || "General"}
                          </span>
                          {hasKeyword && (
                            <span className="inline-flex items-center gap-1 rounded-lg border border-amber-500/30 bg-amber-500/10 px-2 py-0.5 text-[10px] font-bold text-amber-500">
                              <KeyRound className="size-3" /> Keyword
                            </span>
                          )}
                          {task.is_repeatable && (
                            <span className="inline-flex items-center gap-1 rounded-lg border border-gold/30 bg-gold/10 px-2 py-0.5 text-[10px] font-black uppercase tracking-wider text-gold">
                              Daily
                            </span>
                          )}
                        </div>

                        {/* Points Badge */}
                        <div className="flex items-center gap-1.5 bg-gold/15 border border-gold/30 px-3 py-1 rounded-xl text-gold font-mono font-black text-xs shadow-sm">
                          <Coins className="size-3.5 text-gold" />
                          <span>+{task.points} PTS</span>
                        </div>
                      </div>

                      {/* Title and Description */}
                      <div className="space-y-1.5">
                        <h3 className="text-base font-black text-ink-fg leading-snug line-clamp-1 group-hover:text-gold transition-colors">
                          {task.title}
                        </h3>
                        <p className="text-xs font-medium text-ink-muted line-clamp-2 leading-relaxed">
                          {task.description}
                        </p>
                      </div>

                      {/* Rejection Alert Box */}
                      {isRejected && task.admin_note && (
                        <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/25 space-y-1">
                          <p className="text-[10px] font-black uppercase text-rose-400 tracking-wider">
                            Rejection Reason:
                          </p>
                          <p className="text-xs font-medium text-rose-300 leading-snug">
                            {task.admin_note}
                          </p>
                        </div>
                      )}

                      {/* Video Progress Bar */}
                      {isVideo && !isVerified && (
                        <div className="space-y-1.5 pt-1">
                          <div className="flex justify-between text-[11px] font-bold text-ink-muted font-mono">
                            <span>Video Progress</span>
                            <span className="text-ink-fg">
                              {task.watch_count || 0} / {task.video_ad_count} Watched
                            </span>
                          </div>
                          <div className="w-full bg-ink-3 h-2 rounded-full overflow-hidden border border-hairline">
                            <div
                              className="bg-gradient-to-r from-gold to-emerald-400 h-full transition-all duration-500 rounded-full"
                              style={{
                                width: `${Math.min(100, ((task.watch_count || 0) / task.video_ad_count) * 100)}%`,
                              }}
                            />
                          </div>
                          <p className="text-[11px] text-ink-muted font-medium">
                            Earn {task.points} PTS once all {task.video_ad_count} videos are
                            watched.
                          </p>
                        </div>
                      )}

                      {/* Meta details */}
                      <div className="flex items-center gap-4 text-[11px] font-bold text-ink-muted uppercase tracking-wider pt-1">
                        <div className="flex items-center gap-1.5">
                          <Clock className="size-3.5 text-gold" />
                          <span>~2-3 min</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                          <ShieldCheck className="size-3.5 text-emerald-400" />
                          <span>{hasKeyword ? "Keyword Verif." : "Instant Verif."}</span>
                        </div>
                      </div>
                    </div>

                    {/* Action Button Area */}
                    <div className="pt-5 mt-4 border-t border-hairline">
                      <Button
                        className={cn(
                          "w-full rounded-xl font-bold h-11 text-xs transition-all shadow-md cursor-pointer",
                          isVerified
                            ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/20 shadow-none cursor-default"
                            : isPending || currentUi === "verifying"
                              ? "bg-amber-500/15 text-amber-400 border border-amber-500/30 hover:bg-amber-500/20"
                              : currentUi === "awaiting_confirmation"
                                ? "bg-gradient-to-r from-emerald-500 to-teal-500 text-white hover:opacity-95 ring-2 ring-emerald-400/40"
                                : dailyLimitReached && !isVerified
                                  ? "bg-ink-3 text-ink-muted border border-hairline cursor-not-allowed shadow-none"
                                  : isRejected
                                    ? "bg-rose-500/15 text-rose-300 border border-rose-500/30 hover:bg-rose-500/25"
                                    : "bg-gold text-ink hover:bg-gold-soft hover:-translate-y-0.5 shadow-gold/10",
                        )}
                        title={
                          socialLocked ? "Complete your social profile to unlock tasks" : undefined
                        }
                        disabled={
                          socialLocked ||
                          (dailyLimitReached && !isVerified) ||
                          isPending ||
                          isSubmitting ||
                          isVerified
                        }
                        onClick={async () => {
                          const {
                            data: { user: authUser },
                          } = await supabase.auth.getUser();
                          if (!authUser) return;

                          // Fetch profile to check social completion
                          const { data: profile } = await supabase
                            .from("profiles")
                            .select(
                              "twitter_handle, telegram_handle, instagram_handle, facebook_handle",
                            )
                            .eq("id", authUser.id)
                            .single();

                          // Fetch required socials from app_settings
                          const { data: settings } = await (
                            supabase.from("app_settings" as any) as any
                          )
                            .select("value")
                            .eq("key", "welcome_bonus_required_socials")
                            .single();

                          const required = (settings?.value as string[]) || [];
                          const missing = required.filter((social) => {
                            const handleKey = `${social}_handle`;
                            return !(profile as any)?.[handleKey];
                          });

                          if (missing.length > 0) {
                            toast.error(
                              `Please complete your ${missing.join(", ")} handles in your profile before performing tasks.`,
                              {
                                action: {
                                  label: "Go to Profile",
                                  onClick: () => (window.location.href = "/profile"),
                                },
                              },
                            );
                            return;
                          }

                          // Special handling for video tasks
                          if (task.category === "Videos" && task.video_ad_count > 0) {
                            const { data: sessionData, error: sessionError } = await (
                              supabase.rpc as any
                            )("start_video_watch_session", {
                              _user_id: authUser.id,
                              _task_id: task.id,
                            });

                            if (sessionError) {
                              toast.error(sessionError.message);
                              return;
                            }
                            if (!(sessionData as any)?.success) {
                              toast.error(
                                (sessionData as any)?.message || "Unable to start ad session.",
                              );
                              return;
                            }

                            const sessionId = (sessionData as any).session_id as string;
                            const minWatchSeconds =
                              ((sessionData as any).min_watch_seconds as number) ?? 10;

                            const recordWatch = async () => {
                              const { data, error } = await (supabase.rpc as any)(
                                "record_video_watch",
                                {
                                  _user_id: authUser.id,
                                  _task_id: task.id,
                                  _session_id: sessionId,
                                },
                              );

                              if (error) {
                                console.error("Error recording watch:", error);
                                toast.error(error.message);
                              } else if (data && !(data as any).success) {
                                toast.error((data as any).message);
                              } else {
                                const res = data as any;
                                if (res.completed) {
                                  toast.success(res.message);
                                  queryClient.invalidateQueries({ queryKey: ["profile"] });
                                  queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
                                } else {
                                  toast.success(res.message);
                                }
                                refetchTasks();
                              }
                            };

                            if (task.vast_tag_url) {
                              const event = new CustomEvent("play-interstitial-ad", {
                                detail: {
                                  vastUrl: task.vast_tag_url,
                                  onComplete: recordWatch,
                                },
                              });
                              window.dispatchEvent(event);
                              return;
                            }

                            setCompletingTaskId(task.id);
                            toast.info(
                              `Ad playing… please keep this tab open for ${minWatchSeconds} seconds.`,
                            );
                            await new Promise((resolve) =>
                              setTimeout(resolve, minWatchSeconds * 1000),
                            );
                            await recordWatch();
                            setCompletingTaskId(null);
                            return;
                          }

                          const currentUiState = taskUiStates[task.id] || "idle";

                          if (currentUiState === "idle") {
                            // Open Task Instructions Modal before starting
                            setInstructionModalTask(task);
                            return;
                          }

                          if (currentUiState === "awaiting_confirmation") {
                            // Check if this task requires a keyword
                            if (hasKeyword) {
                              setKeywordModalTask(task);
                              setKeywordInput("");
                              setKeywordError(false);
                              return;
                            }

                            // Standard task without keyword
                            setTaskUiStates((prev) => ({ ...prev, [task.id]: "submitting" }));
                            setCompletingTaskId(task.id);

                            const { data, error } = await (supabase.rpc as any)("submit_task", {
                              _user_id: authUser.id,
                              _task_id: task.id,
                            });

                            if (error) {
                              toast.error(error.message);
                              setTaskUiStates((prev) => ({
                                ...prev,
                                [task.id]: "awaiting_confirmation",
                              }));
                            } else if (data && !(data as any).success) {
                              toast.error((data as any).message);
                              setTaskUiStates((prev) => ({
                                ...prev,
                                [task.id]: "awaiting_confirmation",
                              }));
                            } else {
                              confetti({
                                particleCount: 70,
                                spread: 60,
                                origin: { y: 0.6 },
                              });
                              toast.success(
                                (data as any)?.message || "Task submitted for verification!",
                              );
                              refetchTasks();
                              queryClient.invalidateQueries({ queryKey: ["profile"] });
                              queryClient.invalidateQueries({ queryKey: ["daily-task-stats"] });
                              setTaskUiStates((prev) => ({ ...prev, [task.id]: "idle" }));
                            }
                            setCompletingTaskId(null);
                          }
                        }}
                      >
                        {isVerified ? (
                          <span className="flex items-center gap-2">
                            <CheckCircle2 className="size-4 text-emerald-400" />
                            Completed & Rewarded
                          </span>
                        ) : isPending ? (
                          <span className="flex items-center gap-2">
                            <Clock className="size-4 text-amber-400" />
                            Verification In Review...
                          </span>
                        ) : isVideo ? (
                          isSubmitting ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : (
                            <span className="flex items-center gap-1.5">
                              <Play className="size-3.5 fill-ink" />
                              Watch Video ({task.watch_count || 0}/{task.video_ad_count})
                            </span>
                          )
                        ) : currentUi === "verifying" ? (
                          <span className="flex items-center gap-2">
                            <Loader2 className="size-4 animate-spin text-amber-400" />
                            Checking Activity...
                          </span>
                        ) : currentUi === "awaiting_confirmation" ? (
                          <span className="flex items-center gap-1.5">
                            {hasKeyword ? (
                              <KeyRound className="size-4 text-white" />
                            ) : (
                              <CheckCircle className="size-4 text-white" />
                            )}
                            {hasKeyword
                              ? "Enter Keyword to Claim"
                              : `Confirm & Claim (+${task.points} PTS)`}
                          </span>
                        ) : isSubmitting ? (
                          <Loader2 className="size-4 animate-spin" />
                        ) : isRejected ? (
                          <span className="flex items-center gap-2">
                            <XCircle className="size-4 text-rose-400" />
                            Try Task Again
                          </span>
                        ) : dailyLimitReached ? (
                          <span>Daily Limit Reached</span>
                        ) : (
                          <span className="flex items-center gap-1.5">
                            <span>Start Task</span>
                            <ArrowRight className="size-3.5" />
                          </span>
                        )}
                      </Button>
                    </div>
                  </div>
                );
              })
            : !isLoading && (
                <div className="col-span-full rounded-3xl border border-hairline bg-ink-2/60 p-12 text-center space-y-4 backdrop-blur-xl">
                  <div className="size-16 rounded-2xl bg-ink-3 text-gold flex items-center justify-center mx-auto border border-hairline shadow-inner">
                    <Coins className="size-8 text-gold" />
                  </div>
                  <div className="space-y-1.5 max-w-sm mx-auto">
                    <h3 className="font-black text-lg text-ink-fg">No tasks found</h3>
                    <p className="text-xs text-ink-muted font-medium">
                      {activeStatus === "completed"
                        ? "You haven't completed any tasks in this category yet. Switch to Available to explore new tasks!"
                        : activeStatus === "in_progress"
                          ? "You don't have any tasks currently pending verification."
                          : "Check back tomorrow for your next batch of 10 daily tasks."}
                    </p>
                  </div>
                  {activeStatus !== "available" && (
                    <Button
                      onClick={() => {
                        setActiveStatus("available");
                      }}
                      className="rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft px-5 cursor-pointer"
                    >
                      View Available Tasks
                    </Button>
                  )}
                </div>
              )}

          {isLoading &&
            Array.from({ length: 6 }).map((_, i) => (
              <div
                key={i}
                className="rounded-3xl border border-hairline bg-ink-2/40 p-6 h-[260px] animate-pulse space-y-4"
              >
                <div className="flex justify-between">
                  <div className="h-5 w-20 bg-ink-3 rounded-lg" />
                  <div className="h-5 w-16 bg-ink-3 rounded-lg" />
                </div>
                <div className="h-6 w-3/4 bg-ink-3 rounded-lg" />
                <div className="h-12 w-full bg-ink-3 rounded-lg" />
                <div className="h-10 w-full bg-ink-3 rounded-xl mt-auto" />
              </div>
            ))}
        </motion.div>
      )}

      {/* Task Instructions & Start Modal */}
      <Dialog
        open={!!instructionModalTask}
        onOpenChange={(open) => {
          if (!open) setInstructionModalTask(null);
        }}
      >
        <DialogContent className="rounded-3xl max-w-lg bg-ink-2 border border-hairline text-ink-fg p-6 sm:p-7 shadow-2xl backdrop-blur-2xl">
          {instructionModalTask &&
            (() => {
              const parsedKeyword = parseTaskKeywordData(instructionModalTask.icon_name);

              return (
                <>
                  <DialogHeader className="space-y-2 text-left">
                    <div className="flex items-center justify-between gap-2">
                      <span className="inline-flex items-center gap-1 rounded-lg border border-hairline bg-ink-3 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider text-ink-fg">
                        {instructionModalTask.category || "General"}
                      </span>
                      <div className="flex items-center gap-1 bg-gold/15 border border-gold/30 px-3 py-1 rounded-xl text-gold font-mono font-black text-xs">
                        <Coins className="size-3.5 text-gold" />
                        <span>+{instructionModalTask.points} PTS</span>
                      </div>
                    </div>
                    <DialogTitle className="text-xl font-black text-ink-fg leading-snug">
                      {instructionModalTask.title}
                    </DialogTitle>
                    <DialogDescription className="text-xs text-ink-muted">
                      Follow these simple steps carefully to receive your verified points.
                    </DialogDescription>
                  </DialogHeader>

                  <div className="space-y-4 py-3">
                    {/* Task Step Guidance */}
                    <div className="p-4 rounded-2xl bg-ink-3/80 border border-hairline space-y-3">
                      <p className="text-xs font-bold text-ink-fg flex items-center gap-1.5">
                        <ListTodo className="size-4 text-gold" />
                        How to Complete This Task:
                      </p>
                      <ul className="space-y-2.5 text-xs text-ink-muted">
                        <li className="flex items-start gap-2.5">
                          <span className="size-5 rounded-full bg-gold/15 text-gold font-bold text-[10px] flex items-center justify-center shrink-0 mt-0.5">
                            1
                          </span>
                          <span>
                            Click <strong className="text-ink-fg">"Open Task & Start"</strong> below
                            to visit the link in a new tab.
                          </span>
                        </li>
                        <li className="flex items-start gap-2.5">
                          <span className="size-5 rounded-full bg-gold/15 text-gold font-bold text-[10px] flex items-center justify-center shrink-0 mt-0.5">
                            2
                          </span>
                          <span>
                            Read the content, hit like, and share your thoughtful comment or
                            feedback.
                          </span>
                        </li>
                        {parsedKeyword.hasKeyword && (
                          <li className="flex items-start gap-2.5">
                            <span className="size-5 rounded-full bg-amber-500/20 text-amber-400 font-bold text-[10px] flex items-center justify-center shrink-0 mt-0.5">
                              3
                            </span>
                            <span>
                              Locate the secret <strong className="text-amber-400">Keyword</strong>{" "}
                              in the post or comments, copy it, and return here to submit.
                            </span>
                          </li>
                        )}
                        <li className="flex items-start gap-2.5">
                          <span className="size-5 rounded-full bg-emerald-500/20 text-emerald-400 font-bold text-[10px] flex items-center justify-center shrink-0 mt-0.5">
                            {parsedKeyword.hasKeyword ? "4" : "3"}
                          </span>
                          <span>
                            Return to this tab and confirm to immediately receive your{" "}
                            <strong className="text-emerald-400">
                              +{instructionModalTask.points} PTS
                            </strong>
                            !
                          </span>
                        </li>
                      </ul>
                    </div>

                    {/* Hint if keyword task */}
                    {parsedKeyword.hasKeyword && parsedKeyword.hint && (
                      <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-300 flex items-start gap-2">
                        <HelpCircle className="size-4 shrink-0 text-amber-400 mt-0.5" />
                        <span>
                          <strong>Hint:</strong> {parsedKeyword.hint}
                        </span>
                      </div>
                    )}
                  </div>

                  <DialogFooter className="gap-2 sm:gap-0">
                    <Button
                      variant="ghost"
                      onClick={() => setInstructionModalTask(null)}
                      className="rounded-xl text-xs"
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={() => handleStartTaskExecution(instructionModalTask)}
                      className="rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft px-5 gap-2 shadow-md cursor-pointer"
                    >
                      <span>Open Task & Start</span>
                      <ExternalLink className="size-3.5" />
                    </Button>
                  </DialogFooter>
                </>
              );
            })()}
        </DialogContent>
      </Dialog>

      {/* Keyword Verification Modal */}
      <Dialog
        open={!!keywordModalTask}
        onOpenChange={(open) => {
          if (!open) {
            setKeywordModalTask(null);
            setKeywordError(false);
          }
        }}
      >
        <DialogContent className="rounded-3xl max-w-md bg-ink-2 border border-hairline text-ink-fg p-6 sm:p-7 shadow-2xl backdrop-blur-2xl">
          {keywordModalTask &&
            (() => {
              const parsed = parseTaskKeywordData(keywordModalTask.icon_name);

              return (
                <>
                  <DialogHeader className="space-y-2 text-left">
                    <div className="flex items-center gap-2">
                      <div className="size-9 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center border border-amber-500/30">
                        <KeyRound className="size-5" />
                      </div>
                      <div>
                        <DialogTitle className="text-lg font-black text-ink-fg leading-tight">
                          Enter Task Keyword
                        </DialogTitle>
                        <DialogDescription className="text-xs text-ink-muted">
                          Confirm your reading and engagement
                        </DialogDescription>
                      </div>
                    </div>
                  </DialogHeader>

                  <div className="space-y-4 py-2">
                    <p className="text-xs text-ink-muted leading-relaxed">
                      Please enter the verification keyword found in{" "}
                      <strong className="text-ink-fg">"{keywordModalTask.title}"</strong> to confirm
                      you completed the task.
                    </p>

                    {parsed.hint && (
                      <div className="p-3 rounded-xl bg-ink-3/80 border border-hairline text-xs text-ink-muted flex items-start gap-2">
                        <HelpCircle className="size-4 shrink-0 text-gold mt-0.5" />
                        <span>
                          <strong>Hint:</strong> {parsed.hint}
                        </span>
                      </div>
                    )}

                    <div className="space-y-1.5">
                      <label className="text-xs font-bold text-ink-fg">Verification Keyword</label>
                      <Input
                        placeholder="Type or paste the keyword here..."
                        value={keywordInput}
                        onChange={(e) => {
                          setKeywordInput(e.target.value);
                          if (keywordError) setKeywordError(false);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            e.preventDefault();
                            handleVerifyKeywordSubmit();
                          }
                        }}
                        className={cn(
                          "h-11 bg-ink border-hairline rounded-xl text-xs font-mono tracking-wider uppercase",
                          keywordError && "border-rose-500 focus-visible:ring-rose-500",
                        )}
                        autoFocus
                      />
                      {keywordError && (
                        <p className="text-[11px] font-medium text-rose-400">
                          Incorrect keyword. Please verify against the post or comment section.
                        </p>
                      )}
                    </div>
                  </div>

                  <DialogFooter className="gap-2 sm:gap-0 pt-2">
                    <Button
                      variant="ghost"
                      onClick={() => setKeywordModalTask(null)}
                      className="rounded-xl text-xs cursor-pointer"
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={handleVerifyKeywordSubmit}
                      disabled={submittingKeyword || !keywordInput.trim()}
                      className="rounded-xl font-bold text-xs bg-gold text-ink hover:bg-gold-soft px-5 gap-1.5 shadow-md cursor-pointer"
                    >
                      {submittingKeyword ? (
                        <>
                          <Loader2 className="size-3.5 animate-spin" />
                          <span>Verifying...</span>
                        </>
                      ) : (
                        <>
                          <CheckCircle2 className="size-3.5" />
                          <span>Submit & Claim +{keywordModalTask.points} PTS</span>
                        </>
                      )}
                    </Button>
                  </DialogFooter>
                </>
              );
            })()}
        </DialogContent>
      </Dialog>
    </motion.div>
  );
}
