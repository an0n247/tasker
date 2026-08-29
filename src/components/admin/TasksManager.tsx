import { useState } from "react";
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
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  DialogFooter,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import {
  Plus,
  Edit2,
  Trash2,
  Loader2,
  Save,
  CheckCircle2,
  Circle,
  ShieldCheck,
  Star,
  RefreshCw,
  KeyRound,
  FileText,
  BookOpen,
  HelpCircle,
  Sparkles,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/hooks/use-auth";

export function parseTaskKeywordData(iconName: string | null) {
  if (!iconName) return { hasKeyword: false, keyword: "", hint: "" };
  if (iconName.startsWith("{")) {
    try {
      const parsed = JSON.parse(iconName);
      return {
        hasKeyword: true,
        keyword: parsed.keyword || parsed.k || "",
        hint: parsed.hint || parsed.h || "",
      };
    } catch (e) {}
  }
  if (iconName.startsWith("keyword:")) {
    const raw = iconName.replace("keyword:", "");
    if (raw.includes(":::hint:")) {
      const [k, h] = raw.split(":::hint:");
      return { hasKeyword: true, keyword: k || "", hint: h || "" };
    }
    return { hasKeyword: true, keyword: raw, hint: "" };
  }
  return { hasKeyword: true, keyword: iconName, hint: "" };
}

export function TasksManager() {
  const queryClient = useQueryClient();
  const { isAdmin } = useAuth();
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingTask, setEditingTask] = useState<any>(null);

  const [formData, setFormData] = useState({
    title: "",
    description: "",
    points: 0,
    category: "social",
    is_active: true,
    link_url: "",
    verification_required: false,
    is_featured: false,
    is_repeatable: false,
    video_ad_count: 0,
    vast_tag_url: "",
    requires_keyword: false,
    keyword: "",
    keyword_hint: "",
  });

  const { data: tasks, isLoading } = useQuery({
    queryKey: ["admin-tasks"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("tasks" as any)
        .select("*")
        .order("created_at", { ascending: false });

      if (error) throw error;
      return data;
    },
  });

  const upsertTaskMutation = useMutation({
    mutationFn: async (form: typeof formData) => {
      const iconNameValue =
        form.requires_keyword && form.keyword.trim()
          ? JSON.stringify({
              keyword: form.keyword.trim(),
              hint: (form.keyword_hint || "").trim(),
            })
          : null;

      const payload = {
        title: form.title,
        description: form.description,
        points: form.points,
        category: form.category,
        is_active: form.is_active,
        link_url: form.link_url,
        verification_required: form.verification_required,
        is_featured: form.is_featured,
        is_repeatable: form.is_repeatable,
        video_ad_count: form.video_ad_count,
        vast_tag_url: form.vast_tag_url,
        icon_name: iconNameValue,
      };

      if (editingTask) {
        const { error } = await supabase
          .from("tasks" as any)
          .update(payload)
          .eq("id", editingTask.id);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("tasks" as any).insert(payload);
        if (error) throw error;
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-tasks"] });
      setIsDialogOpen(false);
      setEditingTask(null);
      resetForm();
      toast.success(editingTask ? "Task updated" : "Task created");
    },
    onError: (error) => {
      toast.error("Error saving task: " + error.message);
    },
  });

  const deleteTaskMutation = useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase
        .from("tasks" as any)
        .delete()
        .eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin-tasks"] });
      toast.success("Task deleted");
    },
    onError: (error) => {
      toast.error("Error deleting task: " + error.message);
    },
  });

  const resetForm = () => {
    setFormData({
      title: "",
      description: "",
      points: 0,
      category: "social",
      is_active: true,
      link_url: "",
      verification_required: false,
      is_featured: false,
      is_repeatable: false,
      video_ad_count: 0,
      vast_tag_url: "",
      requires_keyword: false,
      keyword: "",
      keyword_hint: "",
    });
  };

  const handleEdit = (task: any) => {
    setEditingTask(task);
    const parsed = parseTaskKeywordData(task.icon_name);

    setFormData({
      title: task.title,
      description: task.description || "",
      points: task.points,
      category: task.category || "social",
      is_active: task.is_active,
      link_url: task.link_url || "",
      verification_required: task.verification_required || false,
      is_featured: task.is_featured || false,
      is_repeatable: task.is_repeatable || false,
      video_ad_count: task.video_ad_count || 0,
      vast_tag_url: task.vast_tag_url || "",
      requires_keyword: parsed.hasKeyword,
      keyword: parsed.keyword,
      keyword_hint: parsed.hint,
    });
    setIsDialogOpen(true);
  };

  if (isLoading)
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h3 className="text-xl font-black uppercase tracking-tight">Manage Tasks</h3>
          <p className="text-sm text-muted-foreground font-medium">
            Create and edit activities for users to earn points.
          </p>
        </div>
        <Dialog
          open={isDialogOpen}
          onOpenChange={(open) => {
            setIsDialogOpen(open);
            if (!open) {
              setEditingTask(null);
              resetForm();
            }
          }}
        >
          <DialogTrigger asChild>
            <Button className="rounded-xl font-black uppercase tracking-widest text-xs h-11 shadow-lg shadow-primary/20 cursor-pointer">
              <Plus className="mr-2 h-4 w-4" />
              Add Task
            </Button>
          </DialogTrigger>
          <DialogContent className="rounded-2xl max-w-md max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="font-black text-xl uppercase tracking-tight">
                {editingTask ? "Edit Task" : "Add New Task"}
              </DialogTitle>
            </DialogHeader>
            <div className="space-y-4 py-4">
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Title
                </label>
                <Input
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  placeholder="e.g. Read Blog & Find Secret Word"
                  className="rounded-xl h-12"
                />
              </div>
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Description & Instructions
                </label>
                <Textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  placeholder="Clear instructions for the user (e.g. Read through the blog and note the secret word)"
                  className="rounded-xl min-h-[80px]"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                    Reward (Points)
                  </label>
                  <Input
                    type="number"
                    value={formData.points}
                    onChange={(e) =>
                      setFormData({ ...formData, points: parseInt(e.target.value) || 0 })
                    }
                    className="rounded-xl h-12"
                  />
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                    Category
                  </label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="w-full rounded-xl h-12 px-3 bg-background border border-input focus:ring-2 focus:ring-primary text-sm font-bold"
                  >
                    <option value="Blog">Blog</option>
                    <option value="social">Social</option>
                    <option value="daily">Daily</option>
                    <option value="survey">Survey</option>
                    <option value="offer">Offer</option>
                    <option value="Videos">Videos</option>
                  </select>
                </div>
              </div>

              {/* Keyword requirement toggle & inputs */}
              <div className="space-y-3 rounded-2xl p-3.5 bg-muted/40 border border-border/60">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <KeyRound className="size-4 text-amber-500" />
                    <div>
                      <p className="text-xs font-bold text-foreground">Require Secret Keyword</p>
                      <p className="text-[10px] text-muted-foreground">
                        Ask users to enter a keyword to confirm completion
                      </p>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className={cn(
                      "rounded-xl px-3 font-bold text-xs h-8 cursor-pointer transition-all",
                      formData.requires_keyword
                        ? "text-amber-600 bg-amber-500/15 border border-amber-500/30 font-black"
                        : "text-muted-foreground",
                    )}
                    onClick={() =>
                      setFormData({ ...formData, requires_keyword: !formData.requires_keyword })
                    }
                  >
                    {formData.requires_keyword ? (
                      <CheckCircle2 className="h-3.5 w-3.5 mr-1.5 text-amber-500" />
                    ) : (
                      <Circle className="h-3.5 w-3.5 mr-1.5" />
                    )}
                    {formData.requires_keyword ? "Enabled" : "Disabled"}
                  </Button>
                </div>

                {formData.requires_keyword && (
                  <div className="pt-2.5 space-y-3 border-t border-border/40">
                    <div className="space-y-1">
                      <label className="text-[10px] font-black uppercase tracking-widest text-amber-600 ml-1">
                        Target Keyword / Secret Code
                      </label>
                      <Input
                        value={formData.keyword}
                        onChange={(e) => setFormData({ ...formData, keyword: e.target.value })}
                        placeholder="e.g. NOBLEGAIN2026"
                        className="rounded-xl h-11 bg-background font-mono font-bold uppercase"
                      />
                      <p className="text-[10px] text-muted-foreground italic ml-1">
                        User input will be verified against this keyword before completing the task.
                      </p>
                    </div>

                    <div className="space-y-1">
                      <label className="text-[10px] font-black uppercase tracking-widest text-amber-600 ml-1 flex items-center gap-1">
                        <HelpCircle className="size-3" /> Keyword Location Hint (Optional)
                      </label>
                      <Input
                        value={formData.keyword_hint}
                        onChange={(e) => setFormData({ ...formData, keyword_hint: e.target.value })}
                        placeholder="e.g. Found in paragraph 3 of the blog article"
                        className="rounded-xl h-11 bg-background text-xs"
                      />
                      <p className="text-[10px] text-muted-foreground italic ml-1">
                        Shown to users in the task instructions modal as a hint where to find it.
                      </p>
                    </div>
                  </div>
                )}
              </div>

              {formData.category === "Videos" && (
                <div className="space-y-2">
                  <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                    Number of Ads to Watch
                  </label>
                  <Input
                    type="number"
                    value={formData.video_ad_count}
                    onChange={(e) =>
                      setFormData({ ...formData, video_ad_count: parseInt(e.target.value) || 0 })
                    }
                    placeholder="e.g. 10"
                    className="rounded-xl h-12"
                  />
                  <p className="text-[10px] text-muted-foreground italic ml-1">
                    Total points will be awarded after user watches all ads.
                  </p>
                </div>
              )}
              {formData.category === "Videos" && (
                <div className="space-y-2">
                  <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                    VAST Tag URL (Optional)
                  </label>
                  <Input
                    value={formData.vast_tag_url}
                    onChange={(e) => setFormData({ ...formData, vast_tag_url: e.target.value })}
                    placeholder="e.g. https://example.com/vast.xml"
                    className="rounded-xl h-12"
                  />
                  <p className="text-[10px] text-muted-foreground italic ml-1">
                    Leave empty to use standard video watch behavior.
                  </p>
                </div>
              )}
              <div className="space-y-2">
                <label className="text-[10px] font-black uppercase tracking-widest text-muted-foreground ml-1">
                  Task Link (URL)
                </label>
                <Input
                  value={formData.link_url}
                  onChange={(e) => setFormData({ ...formData, link_url: e.target.value })}
                  placeholder="e.g. https://blog.example.com/article-1"
                  className="rounded-xl h-12"
                />
              </div>
              <div className="flex flex-wrap items-center gap-4 pt-2">
                <Button
                  variant="ghost"
                  size="sm"
                  className={cn(
                    "rounded-lg px-3 font-bold cursor-pointer",
                    formData.is_active ? "text-green-600 bg-green-500/10" : "text-muted-foreground",
                  )}
                  onClick={() => setFormData({ ...formData, is_active: !formData.is_active })}
                >
                  {formData.is_active ? (
                    <CheckCircle2 className="h-4 w-4 mr-2" />
                  ) : (
                    <Circle className="h-4 w-4 mr-2" />
                  )}
                  {formData.is_active ? "Active" : "Inactive"}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className={cn(
                    "rounded-lg px-3 font-bold cursor-pointer",
                    formData.verification_required
                      ? "text-primary bg-primary/10"
                      : "text-muted-foreground",
                  )}
                  onClick={() =>
                    setFormData({
                      ...formData,
                      verification_required: !formData.verification_required,
                    })
                  }
                >
                  {formData.verification_required ? (
                    <ShieldCheck className="h-4 w-4 mr-2" />
                  ) : (
                    <Circle className="h-4 w-4 mr-2" />
                  )}
                  {formData.verification_required ? "Manual Admin Review" : "Instant Auto-Reward"}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className={cn(
                    "rounded-lg px-3 font-bold cursor-pointer",
                    formData.is_featured
                      ? "text-amber-600 bg-amber-500/10"
                      : "text-muted-foreground",
                  )}
                  onClick={() => setFormData({ ...formData, is_featured: !formData.is_featured })}
                >
                  {formData.is_featured ? (
                    <Star className="h-4 w-4 mr-2" />
                  ) : (
                    <Circle className="h-4 w-4 mr-2" />
                  )}
                  {formData.is_featured ? "Featured Task" : "Standard Task"}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className={cn(
                    "rounded-lg px-3 font-bold cursor-pointer",
                    formData.is_repeatable
                      ? "text-blue-600 bg-blue-500/10"
                      : "text-muted-foreground",
                  )}
                  onClick={() =>
                    setFormData({ ...formData, is_repeatable: !formData.is_repeatable })
                  }
                >
                  {formData.is_repeatable ? (
                    <RefreshCw className="h-4 w-4 mr-2" />
                  ) : (
                    <Circle className="h-4 w-4 mr-2" />
                  )}
                  {formData.is_repeatable ? "Daily Repeatable" : "One-time Task"}
                </Button>
              </div>
            </div>
            <DialogFooter>
              <Button
                variant="outline"
                onClick={() => setIsDialogOpen(false)}
                className="rounded-xl font-bold border-border/40 cursor-pointer"
              >
                Cancel
              </Button>
              <Button
                onClick={() => {
                  if (formData.requires_keyword && !formData.keyword.trim()) {
                    toast.error("Please provide the target keyword or disable Require Keyword.");
                    return;
                  }
                  upsertTaskMutation.mutate(formData);
                }}
                disabled={upsertTaskMutation.isPending || !formData.title || formData.points <= 0}
                className="rounded-xl font-black uppercase tracking-widest text-xs cursor-pointer"
              >
                {upsertTaskMutation.isPending ? (
                  <Loader2 className="h-4 w-4 animate-spin mr-2" />
                ) : (
                  <Save className="h-4 w-4 mr-2" />
                )}
                {editingTask ? "Update Task" : "Create Task"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>

      <div className="rounded-2xl border border-border/50 bg-card overflow-hidden overflow-x-auto">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent border-border/50">
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 min-w-[200px]">
                Task
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Reward
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Category
              </TableHead>
              <TableHead className="font-black uppercase text-[10px] tracking-widest px-6 text-center">
                Keyword & Hint
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
            {tasks?.length === 0 ? (
              <TableRow>
                <TableCell
                  colSpan={6}
                  className="text-center py-12 text-muted-foreground font-medium"
                >
                  No tasks created yet.
                </TableCell>
              </TableRow>
            ) : (
              tasks?.map((task: any) => {
                const parsed = parseTaskKeywordData(task.icon_name);

                return (
                  <TableRow
                    key={task.id}
                    className="border-border/40 hover:bg-accent/5 transition-colors"
                  >
                    <TableCell className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="font-bold">{task.title}</div>
                        {task.is_featured && (
                          <Badge className="bg-amber-500/15 text-amber-600 hover:bg-amber-500/20 border-none font-black text-[9px] h-4 px-1.5 flex items-center gap-0.5">
                            <Star className="h-2.5 w-2.5 fill-current" />
                            FEATURED
                          </Badge>
                        )}
                        {task.is_repeatable && (
                          <Badge className="bg-blue-500/15 text-blue-600 hover:bg-blue-500/20 border-none font-black text-[9px] h-4 px-1.5 flex items-center gap-0.5">
                            <RefreshCw className="h-2.5 w-2.5" />
                            DAILY
                          </Badge>
                        )}
                      </div>
                      <div className="text-xs text-muted-foreground line-clamp-1">
                        {task.description}
                      </div>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      <Badge
                        variant="outline"
                        className="font-bold text-primary border-primary/20 bg-primary/5"
                      >
                        +{task.points} pts
                      </Badge>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      <Badge
                        variant="secondary"
                        className="font-bold uppercase text-[10px] px-2 py-0.5 rounded-lg"
                      >
                        {task.category}
                      </Badge>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      {parsed.hasKeyword ? (
                        <div className="inline-flex flex-col items-center gap-0.5">
                          <Badge className="bg-amber-500/15 text-amber-600 border border-amber-500/30 font-mono text-[10px] font-bold">
                            <KeyRound className="size-3 mr-1" />
                            {parsed.keyword}
                          </Badge>
                          {parsed.hint && (
                            <span
                              className="text-[9px] text-muted-foreground max-w-[120px] truncate"
                              title={parsed.hint}
                            >
                              Hint: {parsed.hint}
                            </span>
                          )}
                        </div>
                      ) : (
                        <span className="text-muted-foreground text-xs">—</span>
                      )}
                    </TableCell>
                    <TableCell className="px-6 py-4 text-center">
                      <Badge
                        className={cn(
                          "font-black uppercase text-[10px] tracking-wider px-2 py-0.5",
                          task.is_active
                            ? "bg-green-500/10 text-green-600"
                            : "bg-muted text-muted-foreground",
                        )}
                      >
                        {task.is_active ? "Active" : "Inactive"}
                      </Badge>
                    </TableCell>
                    <TableCell className="px-6 py-4 text-right">
                      <div className="flex justify-end gap-2">
                        <Button
                          size="sm"
                          variant="ghost"
                          className="h-8 w-8 p-0 text-muted-foreground hover:text-foreground cursor-pointer"
                          onClick={() => handleEdit(task)}
                        >
                          <Edit2 className="h-4 w-4" />
                        </Button>
                        {isAdmin && (
                          <Button
                            size="sm"
                            variant="ghost"
                            className="h-8 w-8 p-0 text-destructive hover:text-destructive hover:bg-destructive/5 cursor-pointer"
                            onClick={() => {
                              if (confirm("Are you sure you want to delete this task?")) {
                                deleteTaskMutation.mutate(task.id);
                              }
                            }}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
