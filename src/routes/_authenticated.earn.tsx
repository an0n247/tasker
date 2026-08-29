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

function EarnPage() {
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
    queryKey: ["tasks"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return [];

      const { data: tasksData } = await supabase
        .from("tasks" as any)
        .select("*, is_repeatable")
        .eq("is_active", true)
        .order("created_at", { ascending: false });
      const { data: submissions } = await supabase
        .from("task_submissions" as any)
        .select("task_id, status, admin_note, created_at")
        .eq("user_id", user.id);
      const { data: videoProgress } = await supabase
        .from("video_ad_progress")
        .select("task_id, watch_count")
        .eq("user_id", user.id);

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
    queryKey: ["daily-task-stats"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return { daily_count: 0 };

      const { data, error } = await supabase
        .from("user_daily_task_counts" as any)
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();

      if (error) console.error("Error fetching daily stats:", error);
      return (data as any) || { daily_count: 0 };
    },
  });

  const dailyCount = dailyStats?.daily_count || 0;
  const dailyLimit = 10;
  const remainingDaily = Math.max(0, dailyLimit - dailyCount);
  const dailyLimitReached = dailyCount >= dailyLimit;

  const { data: socialCheck } = useQuery({
    queryKey: ["social-verification"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return { complete: false, missing: [] as string[] };

      const { data: profile } = await supabase
        .from("profiles")
        .select("twitter_handle, telegram_handle, instagram_handle, facebook_handle")
        .eq("id", user.id)
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


  const filteredTasks = (tasks as any[])?.filter((t: any) => {
    const isVerifiedToday =
      t.status === "verified" &&
      t.submission_date &&
      new Date(t.submission_date).toISOString().split("T")[0] ===
        new Date().toISOString().split("T")[0];
    const isCompletedNonRepeatable = t.status === "verified" && !t.is_repeatable;
    const isPending = t.status === "pending";
    const isRejected = t.status === "rejected";

    let matchesStatus = false;
    if (activeStatus === "completed") {
      matchesStatus = t.status === "verified";
    } else if (activeStatus === "in_progress") {
      matchesStatus = isPending;
    } else if (activeStatus === "rejected") {
      matchesStatus = isRejected;
    } else {
      matchesStatus = !isPending && !isVerifiedToday && !isCompletedNonRepeatable;
    }

    return matchesStatus;
  });

  // Shuffle tasks per user so each user sees a random order
  const shuffledTasks = useMemo(() => {
    if (!filteredTasks) return filteredTasks;
    const arr = [...filteredTasks];
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }, [tasks, activeStatus]);

  // Calculate quick summary metrics
  const availableCount =
    (tasks as any[])?.filter((t: any) => {
      const isVerifiedToday =
        t.status === "verified" &&
        t.submission_date &&
        new Date(t.submission_date).toISOString().split("T")[0] ===
          new Date().toISOString().split("T")[0];
      const isCompletedNonRepeatable = t.status === "verified" && !t.is_repeatable;
      return t.status !== "pending" && !isVerifiedToday && !isCompletedNonRepeatable;
    }).length || 0;

  const inProgressCount = (tasks as any[])?.filter((t: any) => t.status === "pending").length || 0;
  const completedCount = (tasks as any[])?.filter((t: any) => t.status === "verified").length || 0;

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
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const { data, error } = await (supabase.rpc as any)("submit_task", {
        _user_id: user.id,
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
            <span className="text-ink-fg/70 font-medium">Daily verified rewards</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Earn <span className="text-gold">Points</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Complete partner tasks, blogs, social engagements, and video challenges to grow your
            balance.
          </p>
        </div>

        {/* Daily Allowance Tracker Card (desktop only) */}
        <div className="hidden md:block rounded-2xl border border-hairline bg-ink-2/70 p-4 min-w-[260px] shadow-sm backdrop-blur-md">

          <div className="flex items-center justify-between gap-2 mb-2">
            <span className="text-xs font-bold text-ink-muted uppercase tracking-wider flex items-center gap-1.5">
              <Flame className="size-4 text-amber-500 fill-amber-500" />
              Daily Allowance
            </span>
            <span className="text-xs font-black font-mono text-ink-fg">
              {dailyCount} <span className="text-ink-muted">/ {dailyLimit} Tasks</span>
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
              <span className="text-amber-500 font-bold">Limit reached for today</span>
            ) : (
              <span>
                <strong>{remainingDaily}</strong> tasks remaining today
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

        </div>
      </motion.div>

      {/* Task Cards Grid */}
      <motion.div
        variants={fadeInUp}
        className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
      >
        {shuffledTasks?.length
          ? (shuffledTasks as any[]).map((task: any) => {
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
                          Earn {task.points} PTS once all {task.video_ad_count} videos are watched.
                        </p>
                      </div>
                    )}

                    {/* Meta details */}
                    <div className="flex items-center gap-4 text-[11px] font-bold text-ink-muted uppercase tracking-wider pt-1">
                      <div className="flex items-center gap-1.5">
                        <Clock className="size-3.5 text-gold" />
                        <span>~3-5 min</span>
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
                          data: { user },
                        } = await supabase.auth.getUser();
                        if (!user) return;

                        // Fetch profile to check social completion
                        const { data: profile } = await supabase
                          .from("profiles")
                          .select(
                            "twitter_handle, telegram_handle, instagram_handle, facebook_handle",
                          )
                          .eq("id", user.id)
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
                            _user_id: user.id,
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
                                _user_id: user.id,
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
                            _user_id: user.id,
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
                        : "Check back later as new partner tasks are added throughout the day."}
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
                        {instructionModalTask.category || "General Task"}
                      </span>
                      <div className="flex items-center gap-1.5 bg-gold/15 border border-gold/30 px-3 py-1 rounded-xl text-gold font-mono font-black text-xs">
                        <Coins className="size-3.5 text-gold" />
                        <span>+{instructionModalTask.points} PTS</span>
                      </div>
                    </div>
                    <DialogTitle className="text-xl font-black tracking-tight text-ink-fg">
                      {instructionModalTask.title}
                    </DialogTitle>
                  </DialogHeader>

                  <div className="space-y-4 py-2 text-left">
                    {/* Instructions Body */}
                    <div className="rounded-2xl p-4 bg-ink border border-hairline space-y-2">
                      <p className="text-[11px] font-black uppercase tracking-wider text-ink-muted flex items-center gap-1.5">
                        <Info className="size-3.5 text-gold" /> Task Instructions:
                      </p>
                      <p className="text-xs text-ink-fg font-medium leading-relaxed whitespace-pre-line">
                        {instructionModalTask.description ||
                          "Follow the link, complete the requested actions, and return here to claim your reward points."}
                      </p>
                    </div>

                    {/* Keyword alert with location hint */}
                    {parsedKeyword.hasKeyword && (
                      <div className="rounded-2xl p-4 bg-amber-500/10 border border-amber-500/25 space-y-2">
                        <div className="flex items-center gap-2 text-amber-500">
                          <KeyRound className="size-4" />
                          <span className="text-xs font-bold">Secret Keyword Required</span>
                        </div>
                        <p className="text-xs text-ink-muted font-medium leading-relaxed">
                          To claim your points, you will be prompted to enter a secret keyword found
                          on the task page.
                        </p>
                        {parsedKeyword.hint && (
                          <div className="rounded-xl p-2.5 bg-amber-500/15 border border-amber-500/20 flex items-start gap-2">
                            <HelpCircle className="size-3.5 text-amber-500 shrink-0 mt-0.5" />
                            <p className="text-xs font-bold text-amber-500">
                              <span>Hint: </span>
                              <span className="font-medium text-amber-400">
                                {parsedKeyword.hint}
                              </span>
                            </p>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Estimated time and reward notice */}
                    <div className="flex items-center justify-between text-xs text-ink-muted font-medium px-1">
                      <span className="flex items-center gap-1.5">
                        <Clock className="size-3.5 text-gold" /> Est. Time: ~3-5 min
                      </span>
                      <span className="flex items-center gap-1.5 text-emerald-400 font-bold">
                        <CheckCircle className="size-3.5" /> Verified Reward
                      </span>
                    </div>
                  </div>

                  <DialogFooter className="gap-2 sm:gap-0 pt-2">
                    <Button
                      variant="outline"
                      onClick={() => setInstructionModalTask(null)}
                      className="rounded-xl font-bold h-11 text-xs border-hairline hover:bg-ink-3 cursor-pointer"
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={() => handleStartTaskExecution(instructionModalTask)}
                      className="rounded-xl font-bold h-11 text-xs bg-gold text-ink hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10 flex items-center gap-1.5"
                    >
                      {instructionModalTask.link_url ? (
                        <>
                          <span>Proceed to Task Link</span>
                          <ExternalLink className="size-3.5" />
                        </>
                      ) : (
                        <>
                          <span>Begin Task</span>
                          <ArrowRight className="size-3.5" />
                        </>
                      )}
                    </Button>
                  </DialogFooter>
                </>
              );
            })()}
        </DialogContent>
      </Dialog>

      {/* Secret Keyword Verification Modal */}
      <Dialog
        open={!!keywordModalTask}
        onOpenChange={(open) => {
          if (!open) {
            setKeywordModalTask(null);
            setKeywordInput("");
            setKeywordError(false);
          }
        }}
      >
        <DialogContent className="rounded-3xl max-w-md bg-ink-2 border border-hairline text-ink-fg p-6 sm:p-7 shadow-2xl backdrop-blur-2xl">
          {keywordModalTask &&
            (() => {
              const parsedKeyword = parseTaskKeywordData(keywordModalTask.icon_name);

              return (
                <>
                  <DialogHeader className="space-y-2">
                    <div className="size-12 rounded-2xl bg-amber-500/15 border border-amber-500/30 text-amber-500 flex items-center justify-center mb-1">
                      <KeyRound className="size-6" />
                    </div>
                    <DialogTitle className="text-xl font-black tracking-tight text-ink-fg">
                      Enter Secret Keyword
                    </DialogTitle>
                    <DialogDescription className="text-xs text-ink-muted leading-relaxed font-medium">
                      This task requires a secret verification keyword found in the blog article or
                      task page.
                    </DialogDescription>
                  </DialogHeader>

                  <div className="space-y-4 py-2">
                    <div className="rounded-2xl p-4 bg-ink border border-hairline space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-bold text-ink-fg line-clamp-1">
                          {keywordModalTask.title}
                        </span>
                        <span className="text-xs font-black font-mono text-gold bg-gold/10 px-2 py-0.5 rounded-lg border border-gold/20">
                          +{keywordModalTask.points} PTS
                        </span>
                      </div>
                      {keywordModalTask.link_url && (
                        <a
                          href={keywordModalTask.link_url}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1 text-[11px] font-bold text-gold hover:underline"
                        >
                          Re-open Task Article in new tab <ExternalLink className="size-3" />
                        </a>
                      )}
                    </div>

                    {parsedKeyword.hint && (
                      <div className="rounded-xl p-3 bg-amber-500/10 border border-amber-500/20 flex items-start gap-2">
                        <HelpCircle className="size-3.5 text-amber-500 shrink-0 mt-0.5" />
                        <p className="text-xs font-bold text-amber-500">
                          <span>Hint: </span>
                          <span className="font-medium text-amber-400">{parsedKeyword.hint}</span>
                        </p>
                      </div>
                    )}

                    <div className="space-y-1.5">
                      <label className="text-[11px] font-bold uppercase tracking-wider text-ink-muted ml-1">
                        Secret Keyword / Confirmation Word
                      </label>
                      <Input
                        autoFocus
                        value={keywordInput}
                        onChange={(e) => {
                          setKeywordInput(e.target.value);
                          setKeywordError(false);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            e.preventDefault();
                            handleVerifyKeywordSubmit();
                          }
                        }}
                        placeholder="Type secret keyword here..."
                        className={cn(
                          "rounded-xl h-12 bg-ink border font-mono font-bold uppercase text-sm tracking-wider text-ink-fg",
                          keywordError
                            ? "border-rose-500 focus:ring-rose-500"
                            : "border-hairline focus:border-gold",
                        )}
                      />
                      {keywordError && (
                        <p className="text-[11px] font-medium text-rose-400 ml-1">
                          Incorrect keyword! Please check the blog article to find the right code.
                        </p>
                      )}
                    </div>
                  </div>

                  <DialogFooter className="gap-2 sm:gap-0 pt-2">
                    <Button
                      variant="outline"
                      onClick={() => setKeywordModalTask(null)}
                      className="rounded-xl font-bold h-11 text-xs border-hairline hover:bg-ink-3 cursor-pointer"
                    >
                      Cancel
                    </Button>
                    <Button
                      onClick={handleVerifyKeywordSubmit}
                      disabled={submittingKeyword || !keywordInput.trim()}
                      className="rounded-xl font-bold h-11 text-xs bg-gold text-ink hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10"
                    >
                      {submittingKeyword ? (
                        <span className="flex items-center gap-2">
                          <Loader2 className="size-4 animate-spin" /> Verifying...
                        </span>
                      ) : (
                        <span className="flex items-center gap-1.5">
                          <CheckCircle className="size-4" /> Claim {keywordModalTask?.points || 0}{" "}
                          Points
                        </span>
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

export default EarnPage;
