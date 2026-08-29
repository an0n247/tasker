import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { Loader2, Save, Settings2, Shield, Star, ShieldCheck, Check, Sparkles } from "lucide-react";
import { useState, useEffect } from "react";
import { useAuth } from "@/hooks/use-auth";
import { AlertCircle } from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { cn } from "@/lib/utils";

interface AppSetting {
  id: string;
  key: string;
  value: any;
  description: string | null;
  updated_at: string | null;
}

function PermissionManager() {
  const queryClient = useQueryClient();
  const { data: permissions, isLoading } = useQuery({
    queryKey: ["all-role-permissions"],
    queryFn: async () => {
      const { data, error } = await supabase.from("role_permissions").select("*").order("role");
      if (error) throw error;
      return data;
    },
  });

  const toggleMutation = useMutation({
    mutationFn: async ({ id, is_enabled }: { id: string; is_enabled: boolean }) => {
      const { error } = await supabase.from("role_permissions").update({ is_enabled }).eq("id", id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["all-role-permissions"] });
      toast.success("Role permission updated");
    },
  });

  if (isLoading) {
    return (
      <div className="flex justify-center p-8">
        <Loader2 className="size-6 animate-spin text-gold" />
      </div>
    );
  }

  const roles = ["moderator", "task_manager", "tasker"];
  const tabs = ["tasks", "verifications"];

  return (
    <div className="space-y-6">
      {roles.map((role) => (
        <div key={role} className="space-y-3 bg-ink/60 rounded-2xl p-4 border border-hairline">
          <div className="flex items-center justify-between border-b border-hairline pb-2.5">
            <div className="flex items-center gap-2">
              <span
                className={cn(
                  "font-black uppercase tracking-wider text-[11px] px-2.5 py-0.5 rounded-lg border font-mono",
                  role === "moderator"
                    ? "bg-blue-500/15 text-blue-400 border-blue-500/30"
                    : "bg-indigo-500/15 text-indigo-400 border-indigo-500/30",
                )}
              >
                {role} role
              </span>
              <span className="text-[11px] text-ink-muted font-medium">Accessible tabs</span>
            </div>
            <span className="text-[10px] text-ink-muted font-mono">
              {permissions?.filter((p) => p.role === role && p.is_enabled).length || 0} active
            </span>
          </div>

          <div className="grid grid-cols-2 gap-2.5">
            {tabs.map((tab) => {
              const perm = permissions?.find((p) => p.role === role && p.tab_name === tab);
              const isEnabled = perm?.is_enabled ?? false;

              return (
                <div
                  key={tab}
                  className={cn(
                    "flex items-center justify-between p-2.5 rounded-xl border transition-colors",
                    isEnabled
                      ? "bg-ink-2/80 border-gold/25"
                      : "bg-ink-3/40 border-hairline opacity-75",
                  )}
                >
                  <span
                    className={cn(
                      "text-[10px] font-bold uppercase tracking-wider",
                      isEnabled ? "text-ink-fg" : "text-ink-muted",
                    )}
                  >
                    {tab}
                  </span>
                  <Switch
                    checked={isEnabled}
                    onCheckedChange={(checked) => {
                      if (perm) {
                        toggleMutation.mutate({ id: perm.id, is_enabled: checked });
                      } else {
                        supabase
                          .from("role_permissions")
                          .insert({
                            role: role as
                              "admin" | "moderator" | "task_manager" | "tasker" | "user",
                            tab_name: tab,
                            is_enabled: checked,
                          })
                          .then(() =>
                            queryClient.invalidateQueries({ queryKey: ["all-role-permissions"] }),
                          );
                      }
                    }}
                    className="data-[state=checked]:bg-gold scale-90"
                  />
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

export function PlatformSettings() {
  const { isAdmin, isLoading: isAuthLoading } = useAuth();
  const queryClient = useQueryClient();
  const [localValues, setLocalValues] = useState<Record<string, any>>({});

  const { data: settings, isLoading } = useQuery({
    queryKey: ["appSettings"],
    queryFn: async () => {
      const { data, error } = await (supabase.from("app_settings" as any) as any).select("*");
      if (error) throw error;
      return data as AppSetting[];
    },
  });

  useEffect(() => {
    if (settings) {
      const vals: Record<string, any> = {};
      settings.forEach((s) => {
        vals[s.key] = s.value;
      });
      setLocalValues(vals);
    }
  }, [settings]);

  const updateMutation = useMutation({
    mutationFn: async ({ key, value }: { key: string; value: any }) => {
      const { error } = await (supabase.from("app_settings" as any) as any)
        .update({ value, updated_at: new Date().toISOString() })
        .eq("key", key);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["appSettings"] });
      toast.success("Setting saved successfully");
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update setting");
    },
  });

  const handleSave = (key: string) => {
    updateMutation.mutate({ key, value: localValues[key] });
  };

  if (isLoading || isAuthLoading) {
    return (
      <div className="flex h-[350px] w-full items-center justify-center">
        <Loader2 className="size-8 animate-spin text-gold" />
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div className="rounded-3xl border border-rose-500/30 bg-rose-500/10 p-6 text-rose-300">
        <div className="flex items-center gap-3">
          <AlertCircle className="size-6 text-rose-400 shrink-0" />
          <div>
            <h4 className="font-black text-sm uppercase tracking-wider text-rose-200">
              Access Restricted
            </h4>
            <p className="text-xs text-rose-300/80 font-medium mt-0.5">
              Only platform administrators can modify system parameters and role access.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="grid gap-6 lg:grid-cols-12 items-start">
      {/* Left Column: Platform Configuration & Welcome Bonus Settings */}
      <div className="lg:col-span-6 space-y-6">
        {/* Card 1: Platform Configuration */}
        <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-5">
          <div className="flex items-center gap-3 border-b border-hairline pb-4">
            <div className="size-9 rounded-xl bg-gold/15 text-gold flex items-center justify-center border border-gold/25">
              <Settings2 className="size-4" />
            </div>
            <div>
              <h3 className="text-base font-black text-ink-fg">Platform Configuration</h3>
              <p className="text-xs text-ink-muted font-medium">
                Configure global limits and operation rules
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="space-y-1.5 bg-ink p-4 rounded-2xl border border-hairline">
              <Label className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">
                Daily Task Completion Limit
              </Label>
              <div className="flex gap-2 pt-1">
                <Input
                  type="number"
                  value={localValues["daily_task_limit"] ?? 10}
                  onChange={(e) =>
                    setLocalValues((prev) => ({
                      ...prev,
                      daily_task_limit: parseInt(e.target.value) || 0,
                    }))
                  }
                  className="rounded-xl h-11 bg-ink-2 border-hairline text-ink-fg font-mono font-bold"
                />
                <Button
                  className="rounded-xl h-11 px-4 bg-gold text-ink hover:bg-gold-soft font-black text-xs cursor-pointer shadow-md shadow-gold/10 shrink-0"
                  onClick={() => handleSave("daily_task_limit")}
                  disabled={updateMutation.isPending}
                >
                  <Save className="size-4 mr-1.5" />
                  Save
                </Button>
              </div>
              <p className="text-[11px] text-ink-muted font-medium pt-1">
                Maximum tasks a user can complete every 24-hour cycle.
              </p>
            </div>
          </div>
        </div>

        {/* Card 2: Welcome Bonus Settings */}
        <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-5">
          <div className="flex items-center gap-3 border-b border-hairline pb-4">
            <div className="size-9 rounded-xl bg-amber-500/15 text-amber-400 flex items-center justify-center border border-amber-500/25">
              <Star className="size-4" />
            </div>
            <div>
              <h3 className="text-base font-black text-ink-fg">Welcome Bonus & Referral Rewards</h3>
              <p className="text-xs text-ink-muted font-medium">
                Configure signup and onboarding point rewards
              </p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 rounded-2xl bg-ink border border-hairline">
              <div className="space-y-0.5">
                <Label className="text-xs font-bold uppercase tracking-wider text-ink-fg">
                  Enable Welcome Bonus Popup
                </Label>
                <p className="text-[11px] text-ink-muted font-medium">
                  Display welcome bonus modal to newly registered users
                </p>
              </div>
              <Switch
                checked={localValues["welcome_bonus_enabled"] === true}
                onCheckedChange={(checked) => {
                  setLocalValues((prev) => ({ ...prev, welcome_bonus_enabled: checked }));
                  updateMutation.mutate({ key: "welcome_bonus_enabled", value: checked });
                }}
                className="data-[state=checked]:bg-gold"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              <div className="space-y-1.5 bg-ink p-4 rounded-2xl border border-hairline">
                <Label className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">
                  Referee Bonus (Points)
                </Label>
                <div className="flex gap-2 pt-1">
                  <Input
                    type="number"
                    value={localValues["welcome_bonus_amount_referee"] || 0}
                    onChange={(e) =>
                      setLocalValues((prev) => ({
                        ...prev,
                        welcome_bonus_amount_referee: parseInt(e.target.value) || 0,
                      }))
                    }
                    className="rounded-xl h-11 bg-ink-2 border-hairline text-ink-fg font-mono font-bold"
                  />
                  <Button
                    className="rounded-xl h-11 px-3 bg-gold text-ink hover:bg-gold-soft font-black text-xs cursor-pointer shadow-md shadow-gold/10 shrink-0"
                    onClick={() => handleSave("welcome_bonus_amount_referee")}
                    disabled={updateMutation.isPending}
                  >
                    <Save className="size-4" />
                  </Button>
                </div>
              </div>

              <div className="space-y-1.5 bg-ink p-4 rounded-2xl border border-hairline">
                <Label className="text-[11px] font-bold uppercase tracking-wider text-ink-muted">
                  Referrer Bonus (Points)
                </Label>
                <div className="flex gap-2 pt-1">
                  <Input
                    type="number"
                    value={localValues["welcome_bonus_amount_referrer"] || 0}
                    onChange={(e) =>
                      setLocalValues((prev) => ({
                        ...prev,
                        welcome_bonus_amount_referrer: parseInt(e.target.value) || 0,
                      }))
                    }
                    className="rounded-xl h-11 bg-ink-2 border-hairline text-ink-fg font-mono font-bold"
                  />
                  <Button
                    className="rounded-xl h-11 px-3 bg-gold text-ink hover:bg-gold-soft font-black text-xs cursor-pointer shadow-md shadow-gold/10 shrink-0"
                    onClick={() => handleSave("welcome_bonus_amount_referrer")}
                    disabled={updateMutation.isPending}
                  >
                    <Save className="size-4" />
                  </Button>
                </div>
              </div>
            </div>

            <div className="space-y-3 p-4 rounded-2xl bg-ink border border-hairline">
              <Label className="text-xs font-bold uppercase tracking-wider text-ink-fg block">
                Required Social Profiles for Bonus
              </Label>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                {["twitter", "telegram", "instagram", "facebook"].map((social) => (
                  <div
                    key={social}
                    className="flex items-center gap-2 bg-ink-2/80 p-2.5 rounded-xl border border-hairline"
                  >
                    <Switch
                      id={`social-${social}`}
                      checked={
                        Array.isArray(localValues["welcome_bonus_required_socials"]) &&
                        localValues["welcome_bonus_required_socials"].includes(social)
                      }
                      onCheckedChange={(checked) => {
                        const current = Array.isArray(localValues["welcome_bonus_required_socials"])
                          ? [...localValues["welcome_bonus_required_socials"]]
                          : [];
                        let next;
                        if (checked) {
                          next = [...new Set([...current, social])];
                        } else {
                          next = current.filter((s) => s !== social);
                        }
                        setLocalValues((prev) => ({
                          ...prev,
                          welcome_bonus_required_socials: next,
                        }));
                        updateMutation.mutate({
                          key: "welcome_bonus_required_socials",
                          value: next,
                        });
                      }}
                      className="data-[state=checked]:bg-gold scale-90"
                    />
                    <Label
                      htmlFor={`social-${social}`}
                      className="text-xs font-bold capitalize cursor-pointer text-ink-fg"
                    >
                      {social}
                    </Label>
                  </div>
                ))}
              </div>
              <p className="text-[11px] text-ink-muted font-medium">
                Referees must link these social handles on their profile to claim the welcome bonus.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Right Column: Role Permissions Card (Placed beside on desktop) */}
      <div className="lg:col-span-6 space-y-6">
        <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-5">
          <div className="flex items-center gap-3 border-b border-hairline pb-4">
            <div className="size-9 rounded-xl bg-blue-500/15 text-blue-400 flex items-center justify-center border border-blue-500/25">
              <ShieldCheck className="size-4" />
            </div>
            <div>
              <h3 className="text-base font-black text-ink-fg">Role & Staff Permissions</h3>
              <p className="text-xs text-ink-muted font-medium">
                Control which admin consoles each internal role can access
              </p>
            </div>
          </div>

          <PermissionManager />
        </div>
      </div>
    </div>
  );
}
