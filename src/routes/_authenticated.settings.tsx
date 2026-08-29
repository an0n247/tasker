import { createFileRoute, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  User,
  Bell,
  Shield,
  LogOut,
  Camera,
  Check,
  Loader2,
  Sliders,
  Sparkles,
  Lock,
  Smartphone,
  Mail,
  ExternalLink,
  ChevronRight,
  ShieldCheck,
  ArrowRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { uploadImageWithFallback } from "@/lib/upload-image";
import { useState } from "react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { motion } from "framer-motion";

export const Route = createFileRoute("/_authenticated/settings")({
  head: () => ({
    title: "Account Settings & Preferences | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "Customize your Noble Gain experience. Manage notification preferences, security settings, and account privacy.",
      },
      { property: "og:title", content: "Settings | Noble Gain" },
      {
        property: "og:description",
        content: "Tailor your earning experience and manage your account security.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: SettingsPage,
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

function SettingsPage() {
  const queryClient = useQueryClient();
  const [activeSection, setActiveSection] = useState<"notifications" | "security">("notifications");
  const [isUploading, setIsUploading] = useState(false);

  const { data: profile, isLoading } = useQuery({
    queryKey: ["profile"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return null;
      const { data } = await supabase.from("profiles").select("*").eq("id", user.id).single();
      return data;
    },
  });

  const updateProfile = useMutation({
    mutationFn: async (updates: any) => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");
      const { error } = await supabase.from("profiles").update(updates).eq("id", user.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      toast.success("Preferences updated!");
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to update preferences");
    },
  });

  const handleAvatarUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = event.target.files?.[0];
      if (!file) return;

      if (file.size > 10 * 1024 * 1024) {
        toast.error("Image file size must be under 10MB");
        return;
      }

      setIsUploading(true);
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const fileExt = file.name.split(".").pop() || "jpg";
      const filePath = `${user.id}/${Date.now()}.${fileExt}`;

      const url = await uploadImageWithFallback({
        bucket: "avatars",
        path: filePath,
        fileOrBlob: file,
        maxWidth: 400,
        maxHeight: 400,
        quality: 0.88,
      });

      await updateProfile.mutateAsync({ avatar_url: url });
    } catch (error: any) {
      toast.error(error.message || "Failed to upload avatar");
    } finally {
      setIsUploading(false);
      event.target.value = "";
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    window.location.href = "/auth";
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <Loader2 className="size-8 animate-spin text-gold" />
      </div>
    );
  }

  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={staggerContainer}
      className="space-y-8 w-full max-w-5xl mx-auto pb-12"
    >
      {/* Ambient background light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Header */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <Sliders className="size-3.5" />
            <span>Preferences Vault</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Notification & Security Controls</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            Account <span className="text-gold">Settings</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Manage your communication alerts, connected devices, and account privacy.
          </p>
        </div>

        <Button
          asChild
          variant="outline"
          className="rounded-xl font-bold h-11 px-5 text-xs border-hairline bg-ink-2/60 hover:bg-ink-3 text-ink-fg shrink-0 shadow-sm"
        >
          <Link to="/profile">
            <User className="size-4 mr-1.5 text-gold" />
            <span>View Public Profile</span>
          </Link>
        </Button>
      </motion.header>

      {/* Main Grid */}
      <motion.div variants={fadeInUp} className="grid gap-8 md:grid-cols-12 items-start">
        {/* Left Column: Profile Card & Nav */}
        <div className="md:col-span-4 space-y-4">
          <div className="rounded-3xl p-6 bg-ink-2/70 border border-hairline shadow-md text-center backdrop-blur-xl space-y-4">
            <div className="relative inline-block group">
              <Avatar className="size-20 border-4 border-ink shadow-lg bg-ink-3">
                <AvatarImage src={profile?.avatar_url || ""} className="object-cover" />
                <AvatarFallback className="bg-gold/15 text-gold text-xl font-black">
                  {profile?.full_name?.[0] || profile?.email?.[0] || "?"}
                </AvatarFallback>
              </Avatar>
              <label
                htmlFor="avatar-upload"
                className="absolute bottom-0 right-0 p-2 bg-gold text-ink rounded-full shadow-md cursor-pointer hover:scale-110 transition-transform font-bold"
                title="Change Avatar"
              >
                {isUploading ? (
                  <Loader2 className="size-3.5 animate-spin" />
                ) : (
                  <Camera className="size-3.5" />
                )}
                <input
                  id="avatar-upload"
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleAvatarUpload}
                  disabled={isUploading}
                />
              </label>
            </div>
            <div>
              <h3 className="font-black text-base text-ink-fg">
                {profile?.full_name || "Noble Member"}
              </h3>
              <p className="text-xs text-ink-muted font-medium truncate">{profile?.email}</p>
            </div>
          </div>

          {/* Navigation Tabs */}
          <div className="rounded-2xl p-2 bg-ink-2/70 border border-hairline shadow-sm space-y-1">
            <button
              type="button"
              onClick={() => setActiveSection("notifications")}
              className={cn(
                "w-full flex items-center justify-between p-3 rounded-xl text-xs font-bold transition-all cursor-pointer",
                activeSection === "notifications"
                  ? "bg-gold text-ink font-black shadow-sm"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <span className="flex items-center gap-2.5">
                <Bell className="size-4" />
                <span>Notifications</span>
              </span>
              <ChevronRight className="size-3.5 opacity-60" />
            </button>

            <button
              type="button"
              onClick={() => setActiveSection("security")}
              className={cn(
                "w-full flex items-center justify-between p-3 rounded-xl text-xs font-bold transition-all cursor-pointer",
                activeSection === "security"
                  ? "bg-gold text-ink font-black shadow-sm"
                  : "text-ink-muted hover:text-ink-fg hover:bg-ink-3/60",
              )}
            >
              <span className="flex items-center gap-2.5">
                <Shield className="size-4" />
                <span>Security & Privacy</span>
              </span>
              <ChevronRight className="size-3.5 opacity-60" />
            </button>

            <button
              type="button"
              onClick={handleLogout}
              className="w-full flex items-center gap-2.5 p-3 rounded-xl text-xs font-bold text-rose-400 hover:bg-rose-500/10 transition-colors cursor-pointer"
            >
              <LogOut className="size-4" />
              <span>Log Out of Account</span>
            </button>
          </div>
        </div>

        {/* Right Column: Settings Detail Cards */}
        <div className="md:col-span-8 space-y-6">
          {activeSection === "notifications" && (
            <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-6">
              <div className="border-b border-hairline pb-4">
                <h3 className="text-lg font-black text-ink-fg">Notification Preferences</h3>
                <p className="text-xs text-ink-muted font-medium">
                  Control when and how Noble Gain sends alerts
                </p>
              </div>

              <div className="space-y-5">
                <div className="flex items-center justify-between p-4 rounded-2xl bg-ink border border-hairline">
                  <div className="space-y-1">
                    <Label className="text-sm font-black text-ink-fg flex items-center gap-2">
                      <Mail className="size-4 text-gold" />
                      Email Alerts & Statements
                    </Label>
                    <p className="text-xs text-ink-muted font-medium">
                      Receive weekly earning digests and reward redemption codes via email.
                    </p>
                  </div>
                  <Switch
                    checked={profile?.email_notifications ?? true}
                    onCheckedChange={(checked) =>
                      updateProfile.mutate({ email_notifications: checked })
                    }
                    disabled={updateProfile.isPending}
                    className="data-[state=checked]:bg-gold"
                  />
                </div>

                <div className="flex items-center justify-between p-4 rounded-2xl bg-ink border border-hairline">
                  <div className="space-y-1">
                    <Label className="text-sm font-black text-ink-fg flex items-center gap-2">
                      <Smartphone className="size-4 text-gold" />
                      Push Notifications & Task Drops
                    </Label>
                    <p className="text-xs text-ink-muted font-medium">
                      Receive instant real-time notifications when high-yield tasks go live.
                    </p>
                  </div>
                  <Switch
                    checked={profile?.push_notifications ?? true}
                    onCheckedChange={(checked) =>
                      updateProfile.mutate({ push_notifications: checked })
                    }
                    disabled={updateProfile.isPending}
                    className="data-[state=checked]:bg-gold"
                  />
                </div>
              </div>
            </div>
          )}

          {activeSection === "security" && (
            <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-6">
              <div className="border-b border-hairline pb-4">
                <h3 className="text-lg font-black text-ink-fg">Security & Protection</h3>
                <p className="text-xs text-ink-muted font-medium">
                  Manage your cryptographic session and password
                </p>
              </div>

              <div className="space-y-4">
                <div className="rounded-2xl p-4 bg-emerald-500/10 border border-emerald-500/25 flex items-start gap-3">
                  <ShieldCheck className="size-5 text-emerald-400 shrink-0 mt-0.5" />
                  <div className="space-y-0.5">
                    <p className="text-xs font-bold text-emerald-400">
                      Account Protected with SSL/TLS
                    </p>
                    <p className="text-xs text-ink-muted font-medium">
                      All your point transactions, referrals, and credentials are encrypted
                      end-to-end.
                    </p>
                  </div>
                </div>

                <div className="p-4 rounded-2xl bg-ink border border-hairline flex items-center justify-between">
                  <div className="space-y-0.5">
                    <p className="text-xs font-bold text-ink-fg">Change Password</p>
                    <p className="text-xs text-ink-muted font-medium">
                      Update your security passkey from your profile page.
                    </p>
                  </div>
                  <Button
                    asChild
                    className="rounded-xl font-bold h-10 px-4 text-xs bg-gold text-ink hover:bg-gold-soft shadow-sm"
                  >
                    <Link to="/profile">
                      Go to Profile
                      <ArrowRight className="size-3.5 ml-1.5" />
                    </Link>
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

export default SettingsPage;
