import { createFileRoute, redirect, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  User,
  Mail,
  Calendar,
  Coins,
  Share2,
  Award,
  Shield,
  Settings as SettingsIcon,
  Camera,
  Loader2,
  Check,
  Lock,
  Gift,
  ArrowRight,
  Edit3,
  Eye,
  EyeOff,
  Globe,
  X,
  History as HistoryIcon,
  LayoutDashboard,
  Crown,
  Sparkles,
  CheckCircle2,
  Phone,
  MessageSquare,
  KeyRound,
  ExternalLink,
  ShieldCheck,
  AlertCircle,
} from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useState, useEffect, useCallback } from "react";
import { toast } from "sonner";
import { ImageCropper } from "@/components/ImageCropper";
import { uploadImageWithFallback } from "@/lib/upload-image";
import { cn } from "@/lib/utils";
import { motion, AnimatePresence } from "framer-motion";
import { useDebouncedCallback } from "@/hooks/use-debounced-callback";
import { getUsernameStatus, normalizeUsername, toUsernameFieldState } from "@/lib/username-validation";

export const Route = createFileRoute("/_authenticated/profile")({
  head: () => ({
    title: "My Identity & Account Details | Noble Gain",
    meta: [
      {
        name: "description",
        content:
          "View and manage your Noble Gain public identity, social handles, and personal reward milestones.",
      },
      { property: "og:title", content: "My Profile | Noble Gain" },
      {
        property: "og:description",
        content: "Check your earning stats, social connections, and profile details.",
      },
      { property: "og:type", content: "website" },
      { property: "og:image", content: "/logo.png" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: ProfilePage,
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

function ProfilePage() {
  const queryClient = useQueryClient();
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [usernameStatus, setUsernameStatus] = useState<{
    loading: boolean;
    available: boolean | null;
    message: string;
    error: boolean;
  }>({
    loading: false,
    available: null,
    message: "",
    error: false,
  });
  const [countryCode, setCountryCode] = useState("+234");
  const [phoneBody, setPhoneBody] = useState("");
  const [twitter, setTwitter] = useState("");
  const [facebook, setFacebook] = useState("");
  const [telegram, setTelegram] = useState("");
  const [instagram, setInstagram] = useState("");
  const [isUploading, setIsUploading] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [cropImage, setCropImage] = useState<string | null>(null);
  const [isCropOpen, setIsCropOpen] = useState(false);

  const [verifyingHandles, setVerifyingHandles] = useState<Record<string, boolean>>({});
  const [verifiedHandles, setVerifiedHandles] = useState<Record<string, boolean>>({});

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

  const resetForm = () => {
    if (profile?.full_name) setFullName(profile.full_name);
    if (profile?.username) setUsername(profile.username);
    if (profile?.avatar_url) setAvatarUrl(profile.avatar_url);
    if (profile?.twitter_handle) {
      setTwitter(profile.twitter_handle);
      setVerifiedHandles((prev) => ({ ...prev, twitter: true }));
    }
    if (profile?.facebook_handle) {
      setFacebook(profile.facebook_handle);
      setVerifiedHandles((prev) => ({ ...prev, facebook: true }));
    }
    if (profile?.telegram_handle) {
      setTelegram(profile.telegram_handle);
      setVerifiedHandles((prev) => ({ ...prev, telegram: true }));
    }
    if (profile?.instagram_handle) {
      setInstagram(profile.instagram_handle);
      setVerifiedHandles((prev) => ({ ...prev, instagram: true }));
    }
    if (profile?.phone_number) {
      const parts = profile.phone_number.split(" ");
      if (parts.length >= 2 && parts[0]) {
        setCountryCode(parts[0]);
        setPhoneBody(parts.slice(1).join(" "));
      } else {
        setPhoneBody(profile.phone_number);
      }
    }
  };

  useEffect(() => {
    if (!isEditing && profile) {
      const nextVerified = { twitter: !!profile.twitter_handle, facebook: !!profile.facebook_handle, telegram: !!profile.telegram_handle, instagram: !!profile.instagram_handle };
      setVerifiedHandles((prev) => ({ ...prev, ...nextVerified }));
      resetForm();
    }
  }, [profile, isEditing]);

  const checkUsernameAvailability = useCallback(async (rawValue: string) => {
    const normalized = normalizeUsername(rawValue);
    const currentUsername = normalizeUsername(profile?.username || "");

    if (!normalized) {
      setUsernameStatus({ loading: false, available: null, message: "", error: false });
      return;
    }

    if (normalized === currentUsername) {
      setUsernameStatus({
        loading: false,
        available: true,
        message: "This is your current username.",
        error: false,
      });
      return;
    }

    if (normalized.length < 3) {
      setUsernameStatus(toUsernameFieldState(getUsernameStatus(rawValue)));
      return;
    }

    if (!/^[a-z0-9_]+$/.test(normalized)) {
      setUsernameStatus({
        loading: false,
        available: false,
        message: "Use only letters, numbers, and underscores.",
        error: true,
      });
      return;
    }

    setUsernameStatus({
      loading: true,
      available: null,
      message: "Checking username availability...",
      error: false,
    });

    try {
      const { data, error: rpcError } = await supabase.rpc("check_username_available", {
        _username: normalized,
      });

      if (rpcError) throw rpcError;

      const available = data === true;
      setUsernameStatus({
        loading: false,
        available,
        message: available ? "Username available." : "Username is already taken.",
        error: !available,
      });
    } catch (error) {
      console.error("Username availability check failed:", error);
      setUsernameStatus({
        loading: false,
        available: null,
        message: "Could not verify username availability. Please try again.",
        error: true,
      });
    }
  }, [profile?.username]);

  const debouncedUsernameCheck = useDebouncedCallback((nextUsername: string) => {
    void checkUsernameAvailability(nextUsername);
  }, 500);

  const handleManualVerify = async (type: string, handle: string) => {
    if (!handle || getValidationError(handle, type)) return;

    setVerifyingHandles((prev) => ({ ...prev, [type]: true }));
    await new Promise((resolve) => setTimeout(resolve, 1200));

    setVerifyingHandles((prev) => ({ ...prev, [type]: false }));
    setVerifiedHandles((prev) => ({ ...prev, [type]: true }));
    toast.success(`${type.charAt(0).toUpperCase() + type.slice(1)} handle verified!`);
  };

  const cleanHandle = (handle: string, type: string) => {
    if (!handle) return "";
    let clean = handle.trim();

    const bases = {
      twitter: ["twitter.com/", "x.com/"],
      telegram: ["t.me/", "telegram.me/"],
      facebook: ["facebook.com/", "fb.com/"],
      instagram: ["instagram.com/"],
    };

    const platformBases = bases[type as keyof typeof bases];
    if (platformBases) {
      for (const base of platformBases) {
        if (clean.toLowerCase().includes(base)) {
          const parts = clean.split(new RegExp(base, "i"));
          if (parts.length > 1) {
            const handlePart = parts[1];
            if (handlePart) {
              const segments = handlePart.split("/");
              const firstSegment = segments[0];
              if (firstSegment) {
                const querySegments = firstSegment.split("?");
                const finalHandle = querySegments[0];
                if (finalHandle) {
                  clean = finalHandle;
                }
              }
            }
          }
          break;
        }
      }
    }

    if (clean.startsWith("@")) clean = clean.slice(1);
    clean = clean.replace(/^\/+|\/+$/g, "");

    return clean;
  };

  const getValidationError = (handle: string, type: string) => {
    if (!handle) return null;
    const clean = cleanHandle(handle, type);

    if (type === "twitter") {
      if (clean.length < 4) return "Too short (min 4)";
      if (clean.length > 15) return "Too long (max 15)";
      if (!/^[a-zA-Z0-9_]+$/.test(clean)) return "Invalid characters";
    }
    if (type === "telegram") {
      if (clean.length < 5) return "Too short (min 5)";
      if (clean.length > 32) return "Too long (max 32)";
      if (!/^[a-zA-Z0-9_]+$/.test(clean)) return "Invalid characters";
    }
    if (type === "facebook") {
      if (clean.length < 5) return "Too short (min 5)";
      if (!/^[a-zA-Z0-9.]+$/.test(clean)) return "Invalid characters";
    }
    if (type === "instagram") {
      if (clean.length > 30) return "Too long (max 30)";
      if (!/^[a-zA-Z0-9._]+$/.test(clean)) return "Invalid characters";
    }
    return null;
  };

  const validateHandle = (handle: string, type: string) => {
    return getValidationError(handle, type) === null;
  };

  const updateProfile = useMutation({
    mutationFn: async (updates: any) => {
      if (updates.username) {
        const normalizedUsername = normalizeUsername(updates.username);
        if (normalizedUsername.length < 3) {
          throw new Error("Username must be at least 3 characters.");
        }
        if (!/^[a-z0-9_]+$/.test(normalizedUsername)) {
          throw new Error("Username can only contain letters, numbers, and underscores.");
        }
        const currentUsername = normalizeUsername(profile?.username || "");
        if (normalizedUsername !== currentUsername && (usernameStatus.loading || usernameStatus.available === false || usernameStatus.error)) {
          throw new Error("Please choose an available username.");
        }
      }

      if (updates.twitter_handle && !validateHandle(updates.twitter_handle, "twitter")) {
        throw new Error("Invalid Twitter handle format");
      }
      if (updates.telegram_handle && !validateHandle(updates.telegram_handle, "telegram")) {
        throw new Error("Invalid Telegram handle format");
      }

      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");
      const { error } = await supabase.from("profiles").update(updates).eq("id", user.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["profile"] });
      queryClient.invalidateQueries({ queryKey: ["social-verification"] });
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      toast.success("Profile updated successfully!");
      setIsEditing(false);
    },
    onError: (error: any) => toast.error(error.message || "Failed to update profile"),
  });
  const handleAvatarSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      toast.error("Image file size must be under 10MB");
      return;
    }

    const reader = new FileReader();
    reader.onload = () => {
      setCropImage(reader.result as string);
      setIsCropOpen(true);
    };
    reader.readAsDataURL(file);
    event.target.value = "";
  };

  const handleAvatarUpload = async (blob: Blob) => {
    try {
      setIsCropOpen(false);
      setIsUploading(true);
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not authenticated");

      const filePath = `${user.id}/${Date.now()}.jpg`;
      const url = await uploadImageWithFallback({
        bucket: "avatars",
        path: filePath,
        fileOrBlob: blob,
        maxWidth: 400,
        maxHeight: 400,
        quality: 0.88,
      });

      setAvatarUrl(url);

      // Persist directly to DB
      const { error: updateDbError } = await supabase
        .from("profiles")
        .update({ avatar_url: url })
        .eq("id", user.id);

      if (updateDbError) {
        throw new Error(`Failed to save avatar URL: ${updateDbError.message}`);
      }

      queryClient.invalidateQueries({ queryKey: ["profile"] });
      toast.success("Profile picture updated successfully!");
    } catch (error: any) {
      console.error("Avatar upload error:", error);
      toast.error(error.message || "Failed to upload avatar");
    } finally {
      setIsUploading(false);
      setCropImage(null);
    }
  };

  const handlePasswordChange = async (e: React.FormEvent): Promise<void> => {
    e.preventDefault();
    if (!newPassword || newPassword.length < 6) {
      toast.error("Password must be at least 6 characters");
      return;
    }
    setIsChangingPassword(true);
    try {
      const { error } = await supabase.auth.updateUser({ password: newPassword });
      if (error) throw error;
      toast.success("Password updated successfully!");
      setNewPassword("");
    } catch (error: any) {
      toast.error(error.message || "Failed to update password");
    } finally {
      setIsChangingPassword(false);
    }
  };

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

  const { data: authInfo } = useQuery({
    queryKey: ["authInfo"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return { isAdmin: false, isModerator: false, isTasker: false };

      const [{ data: isAdmin }, { data: isModerator }, { data: isTasker }] = await Promise.all([
        supabase.rpc("has_role", { _user_id: user.id, _role: "admin" }),
        supabase.rpc("has_role", { _user_id: user.id, _role: "moderator" }),
        supabase.rpc("has_role", { _user_id: user.id, _role: "tasker" }),
      ]);

      return { isAdmin, isModerator, isTasker };
    },
  });

  const isAdmin = authInfo?.isAdmin || false;
  const isModerator = authInfo?.isModerator || false;
  const isTasker = (authInfo?.isTasker as boolean) || false;
  const hasSpecialRole = isAdmin || isModerator || isTasker;

  const pointsBalance = profile?.points_balance || 0;
  const currentLevel = Math.floor(pointsBalance / 1000) + 1;
  const levelProgress = ((pointsBalance % 1000) / 1000) * 100;

  // Active DP display prioritizing state then DB
  const currentAvatarDisplay = avatarUrl || profile?.avatar_url || "";

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
      className="space-y-8 w-full max-w-7xl mx-auto pb-12"
    >
      {/* Background ambient light */}
      <div className="pointer-events-none fixed inset-0 -z-10 ink-dots opacity-20 [mask-image:radial-gradient(ellipse_at_top,black,transparent_70%)]" />

      {/* Hidden file input for avatar upload */}
      <input
        id="avatar-upload"
        type="file"
        accept="image/png,image/jpeg,image/webp,image/jpg"
        className="hidden"
        onChange={handleAvatarSelect}
        disabled={isUploading}
      />

      {/* Header Banner */}
      <motion.header
        variants={fadeInUp}
        className="flex flex-col md:flex-row md:items-center justify-between gap-5 border-b border-hairline/70 pb-6"
      >
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/25 text-[11px] font-bold text-gold tracking-widest uppercase">
            <User className="size-3.5" />
            <span>Member Identity</span>
            <span className="text-hairline">•</span>
            <span className="text-ink-fg/70 font-medium">Account Settings & Verification</span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
            My <span className="text-gold">Profile</span>
          </h1>
          <p className="text-sm font-medium text-ink-muted">
            Manage your public identity, link verified social profiles, and track your account tier
            status.
          </p>
        </div>

        <Button
          variant={isEditing ? "outline" : "default"}
          className={cn(
            "rounded-xl font-bold h-11 px-5 text-xs transition-all shadow-md cursor-pointer",
            isEditing
              ? "border-hairline bg-ink-2 hover:bg-ink-3 text-ink-fg"
              : "bg-gold text-ink hover:bg-gold-soft shadow-gold/10 font-black",
          )}
          onClick={() => {
            if (isEditing) {
              resetForm();
              setIsEditing(false);
            } else {
              setIsEditing(true);
            }
          }}
        >
          {isEditing ? (
            <span className="flex items-center gap-2">
              <X className="size-4" /> Cancel Editing
            </span>
          ) : (
            <span className="flex items-center gap-2">
              <Edit3 className="size-4" /> Edit Profile Details
            </span>
          )}
        </Button>
      </motion.header>

      {/* Image Cropper Modal */}
      {cropImage && (
        <ImageCropper
          open={isCropOpen}
          image={cropImage}
          onCancel={() => {
            setIsCropOpen(false);
            setCropImage(null);
          }}
          onCropComplete={handleAvatarUpload}
        />
      )}

      {/* Main Grid */}
      <motion.div variants={fadeInUp} className="grid gap-8 md:grid-cols-12 items-start">
        {/* Left Column: Profile Card & Tier Progression */}
        <div className="md:col-span-5 space-y-6">
          <div className="rounded-3xl border border-hairline bg-ink-2/70 shadow-lg overflow-hidden backdrop-blur-xl">
            {/* Ambient Top Glow Banner */}
            <div className="h-28 bg-gradient-to-r from-gold/20 via-emerald-500/20 to-teal-500/20 relative">
              <div className="absolute top-3 right-3">
                <span className="bg-ink/80 backdrop-blur-md text-gold border border-gold/30 font-mono font-black text-xs px-2.5 py-1 rounded-xl shadow-sm">
                  Tier {currentLevel} VIP
                </span>
              </div>
            </div>

            <div className="relative pt-0 pb-8 px-6 text-center -mt-14">
              <div className="inline-block relative mb-4 group">
                <Avatar className="size-24 border-4 border-ink shadow-xl bg-ink-3">
                  <AvatarImage src={currentAvatarDisplay} className="object-cover" />
                  <AvatarFallback className="bg-gold/15 text-gold text-2xl font-black">
                    {(profile?.username?.[0] || profile?.full_name?.[0] || "?").toUpperCase()}
                  </AvatarFallback>
                </Avatar>

                {/* Camera upload overlay */}
                <button
                  type="button"
                  onClick={() => document.getElementById("avatar-upload")?.click()}
                  className="absolute inset-0 bg-ink/75 rounded-full opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center text-gold cursor-pointer border-2 border-gold/40 shadow-lg"
                  title="Upload new profile picture"
                >
                  {isUploading ? (
                    <Loader2 className="size-6 animate-spin text-gold" />
                  ) : (
                    <>
                      <Camera className="size-5" />
                      <span className="text-[9px] font-black uppercase tracking-wider mt-0.5">
                        Change DP
                      </span>
                    </>
                  )}
                </button>
              </div>

              <div className="space-y-1 mb-6">
                <h2 className="text-xl font-black text-ink-fg">
                  {fullName || profile?.full_name || "Noble Member"}
                </h2>
                <p className="text-xs font-bold text-ink-muted">
                  @
                  {username || profile?.username
                    ? (username || profile?.username || "").charAt(0).toUpperCase() +
                      (username || profile?.username || "").slice(1)
                    : "user"}
                </p>
              </div>

              {/* 2-Metric Balance Bar */}
              <div className="grid grid-cols-2 gap-3 py-4 border-y border-hairline mb-6">
                <div className="space-y-0.5 text-center">
                  <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                    Vault Balance
                  </p>
                  <p className="font-black font-mono text-base text-gold">
                    {pointsBalance.toLocaleString()} <span className="text-[10px]">PTS</span>
                  </p>
                </div>
                <div className="space-y-0.5 text-center border-l border-hairline">
                  <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                    Referral Network
                  </p>
                  <p className="font-black font-mono text-base text-ink-fg">
                    {referralCount} <span className="text-[10px] text-ink-muted">Invites</span>
                  </p>
                </div>
              </div>

              {/* Tier Progress */}
              <div className="space-y-2 text-left bg-ink rounded-2xl p-4 border border-hairline">
                <div className="flex justify-between text-xs font-bold">
                  <span className="text-ink-muted">Milestone Progress</span>
                  <span className="text-gold font-mono">{pointsBalance % 1000} / 1000 PTS</span>
                </div>
                <div className="h-2 bg-ink-3 rounded-full overflow-hidden border border-hairline">
                  <div
                    className="h-full bg-gradient-to-r from-gold to-emerald-400 rounded-full transition-all duration-500"
                    style={{ width: `${levelProgress}%` }}
                  />
                </div>
                <p className="text-[11px] text-ink-muted font-medium pt-1">
                  Earn {1000 - (pointsBalance % 1000)} more PTS to level up to{" "}
                  <strong>Tier {currentLevel + 1}</strong>!
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: Dynamic Form / Detail Hub */}
        <div className="md:col-span-7 space-y-6">
          {isEditing ? (
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              className="space-y-6"
            >
              {/* Profile Details Edit Card */}
              <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-6">
                <div>
                  <h3 className="text-lg font-black text-ink-fg">Edit Profile Information</h3>
                  <p className="text-xs text-ink-muted font-medium">
                    Update your public identity, avatar, and phone number
                  </p>
                </div>

                <div className="space-y-4">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="full-name"
                      className="text-xs font-bold uppercase tracking-wider text-ink-muted"
                    >
                      Full Name
                    </Label>
                    <Input
                      id="full-name"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      className="rounded-xl h-11 bg-ink border-hairline text-ink-fg font-medium"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <Label
                      htmlFor="username"
                      className="text-xs font-bold uppercase tracking-wider text-ink-muted"
                    >
                      Username
                    </Label>
                    <div className="relative">
                      <Input
                        id="username"
                        value={username}
                        onChange={(e) => {
                          const nextValue = normalizeUsername(e.target.value);
                          setUsername(nextValue);

                          if (!nextValue) {
                            setUsernameStatus({
                              loading: false,
                              available: null,
                              message: "",
                              error: false,
                            });
                            return;
                          }

                          if (nextValue.length < 3 || !/^[a-z0-9_]+$/.test(nextValue)) {
                            setUsernameStatus({
                              loading: false,
                              available: false,
                              message: getUsernameStatus(nextValue).message,
                              error: true,
                            });
                            return;
                          }

                          debouncedUsernameCheck(nextValue);
                        }}
                        className={cn(
                          "rounded-xl h-11 bg-ink border-hairline text-ink-fg font-medium pr-12",
                          usernameStatus.available === true && "border-green-500/60",
                          usernameStatus.available === false && "border-destructive/60",
                        )}
                      />
                      {usernameStatus.loading && (
                        <Loader2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-muted-foreground" />
                      )}
                      {usernameStatus.available === true && !usernameStatus.loading && (
                        <CheckCircle2 className="absolute right-4 top-1/2 h-4 w-4 -translate-y-1/2 text-green-500" />
                      )}
                      {usernameStatus.available === false && !usernameStatus.loading && (
                        <span className="absolute right-4 top-1/2 -translate-y-1/2 text-sm font-black text-destructive">
                          !
                        </span>
                      )}
                    </div>
                    {usernameStatus.message && (
                      <p
                        className={cn(
                          "text-xs font-semibold",
                          usernameStatus.error ? "text-destructive" : "text-green-600",
                        )}
                      >
                        {usernameStatus.error ? "✕ " : "✓ "}
                        {usernameStatus.message}
                      </p>
                    )}
                  </div>

                  <div className="space-y-1.5">
                    <Label
                      htmlFor="avatar-url"
                      className="text-xs font-bold uppercase tracking-wider text-ink-muted"
                    >
                      Profile Picture (DP)
                    </Label>
                    <div className="flex gap-2">
                      <Input
                        id="avatar-url"
                        value={avatarUrl}
                        onChange={(e) => setAvatarUrl(e.target.value)}
                        className="rounded-xl h-11 bg-ink border-hairline text-ink-fg font-medium flex-1 text-xs"
                        placeholder="https://example.com/photo.jpg or click camera to upload"
                      />
                      <Button
                        type="button"
                        variant="outline"
                        className="rounded-xl h-11 border-hairline bg-ink hover:bg-ink-3 text-gold cursor-pointer px-4 gap-2 text-xs font-bold shrink-0"
                        onClick={() => document.getElementById("avatar-upload")?.click()}
                        title="Upload file directly"
                        disabled={isUploading}
                      >
                        {isUploading ? (
                          <Loader2 className="size-4 animate-spin" />
                        ) : (
                          <Camera className="size-4" />
                        )}
                        <span>Upload DP</span>
                      </Button>
                    </div>
                  </div>

                  <div className="space-y-1.5">
                    <Label
                      htmlFor="phone-number"
                      className="text-xs font-bold uppercase tracking-wider text-ink-muted"
                    >
                      Phone Number
                    </Label>
                    <div className="flex gap-2">
                      <Select value={countryCode} onValueChange={setCountryCode}>
                        <SelectTrigger className="w-[110px] rounded-xl h-11 bg-ink border-hairline text-ink-fg font-bold">
                          <SelectValue placeholder="Code" />
                        </SelectTrigger>
                        <SelectContent className="bg-ink-2 border-hairline text-ink-fg">
                          <SelectItem value="+234">+234 (NG)</SelectItem>
                          <SelectItem value="+1">+1 (US)</SelectItem>
                          <SelectItem value="+44">+44 (UK)</SelectItem>
                          <SelectItem value="+91">+91 (IN)</SelectItem>
                          <SelectItem value="+27">+27 (ZA)</SelectItem>
                          <SelectItem value="+254">+254 (KE)</SelectItem>
                          <SelectItem value="+233">+233 (GH)</SelectItem>
                        </SelectContent>
                      </Select>
                      <Input
                        id="phone-number"
                        value={phoneBody}
                        onChange={(e) => setPhoneBody(e.target.value)}
                        className="flex-1 rounded-xl h-11 bg-ink border-hairline text-ink-fg font-medium font-mono"
                        placeholder="8123456789"
                      />
                    </div>
                  </div>
                </div>

                {/* Social Handles Section */}
                <div className="space-y-4 pt-4 border-t border-hairline">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-black text-ink-fg flex items-center gap-2">
                      <Globe className="size-4 text-gold" />
                      Linked Social Profiles
                    </h4>
                    <span className="text-[11px] font-bold text-amber-500 bg-amber-500/10 px-2 py-0.5 rounded-lg border border-amber-500/20">
                      Required for Tasks
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Twitter / X */}
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="twitter"
                        className="text-[11px] font-bold uppercase tracking-wider text-ink-muted"
                      >
                        Twitter / X
                      </Label>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center flex-1">
                          <span className="inline-flex items-center px-3 rounded-l-xl border border-r-0 border-hairline bg-ink-3 text-ink-muted text-xs h-11 font-mono">
                            x.com/
                          </span>
                          <Input
                            id="twitter"
                            value={twitter}
                            onChange={(e) => {
                              setTwitter(cleanHandle(e.target.value, "twitter"));
                              setVerifiedHandles((prev) => ({ ...prev, twitter: false }));
                            }}
                            className="rounded-l-none rounded-r-xl h-11 bg-ink border-hairline text-xs font-mono text-ink-fg"
                            placeholder="username"
                          />
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          className={cn(
                            "h-11 rounded-xl font-bold px-3 transition-all cursor-pointer",
                            verifiedHandles["twitter"]
                              ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                              : "bg-gold/15 text-gold border border-gold/30 hover:bg-gold/25",
                          )}
                          disabled={
                            !twitter ||
                            !!getValidationError(twitter, "twitter") ||
                            verifyingHandles["twitter"] ||
                            verifiedHandles["twitter"]
                          }
                          onClick={() => handleManualVerify("twitter", twitter)}
                        >
                          {verifyingHandles["twitter"] ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : verifiedHandles["twitter"] ? (
                            <Check className="size-4" />
                          ) : (
                            "Verify"
                          )}
                        </Button>
                      </div>
                      {twitter && (
                        <p className="text-[10px] text-ink-muted">
                          {getValidationError(twitter, "twitter") ? (
                            <span className="text-rose-400 font-bold">
                              {getValidationError(twitter, "twitter")}
                            </span>
                          ) : (
                            <span className="text-emerald-400">✓ Valid handle format</span>
                          )}
                        </p>
                      )}
                    </div>

                    {/* Telegram */}
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="telegram"
                        className="text-[11px] font-bold uppercase tracking-wider text-ink-muted"
                      >
                        Telegram
                      </Label>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center flex-1">
                          <span className="inline-flex items-center px-3 rounded-l-xl border border-r-0 border-hairline bg-ink-3 text-ink-muted text-xs h-11 font-mono">
                            t.me/
                          </span>
                          <Input
                            id="telegram"
                            value={telegram}
                            onChange={(e) => {
                              setTelegram(cleanHandle(e.target.value, "telegram"));
                              setVerifiedHandles((prev) => ({ ...prev, telegram: false }));
                            }}
                            className="rounded-l-none rounded-r-xl h-11 bg-ink border-hairline text-xs font-mono text-ink-fg"
                            placeholder="username"
                          />
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          className={cn(
                            "h-11 rounded-xl font-bold px-3 transition-all cursor-pointer",
                            verifiedHandles["telegram"]
                              ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                              : "bg-gold/15 text-gold border border-gold/30 hover:bg-gold/25",
                          )}
                          disabled={
                            !telegram ||
                            !!getValidationError(telegram, "telegram") ||
                            verifyingHandles["telegram"] ||
                            verifiedHandles["telegram"]
                          }
                          onClick={() => handleManualVerify("telegram", telegram)}
                        >
                          {verifyingHandles["telegram"] ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : verifiedHandles["telegram"] ? (
                            <Check className="size-4" />
                          ) : (
                            "Verify"
                          )}
                        </Button>
                      </div>
                      {telegram && (
                        <p className="text-[10px] text-ink-muted">
                          {getValidationError(telegram, "telegram") ? (
                            <span className="text-rose-400 font-bold">
                              {getValidationError(telegram, "telegram")}
                            </span>
                          ) : (
                            <span className="text-emerald-400">✓ Valid handle format</span>
                          )}
                        </p>
                      )}
                    </div>

                    {/* Facebook */}
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="facebook"
                        className="text-[11px] font-bold uppercase tracking-wider text-ink-muted"
                      >
                        Facebook
                      </Label>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center flex-1">
                          <span className="inline-flex items-center px-3 rounded-l-xl border border-r-0 border-hairline bg-ink-3 text-ink-muted text-xs h-11 font-mono">
                            fb.com/
                          </span>
                          <Input
                            id="facebook"
                            value={facebook}
                            onChange={(e) => {
                              setFacebook(cleanHandle(e.target.value, "facebook"));
                              setVerifiedHandles((prev) => ({ ...prev, facebook: false }));
                            }}
                            className="rounded-l-none rounded-r-xl h-11 bg-ink border-hairline text-xs font-mono text-ink-fg"
                            placeholder="username"
                          />
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          className={cn(
                            "h-11 rounded-xl font-bold px-3 transition-all cursor-pointer",
                            verifiedHandles["facebook"]
                              ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                              : "bg-gold/15 text-gold border border-gold/30 hover:bg-gold/25",
                          )}
                          disabled={
                            !facebook ||
                            !!getValidationError(facebook, "facebook") ||
                            verifyingHandles["facebook"] ||
                            verifiedHandles["facebook"]
                          }
                          onClick={() => handleManualVerify("facebook", facebook)}
                        >
                          {verifyingHandles["facebook"] ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : verifiedHandles["facebook"] ? (
                            <Check className="size-4" />
                          ) : (
                            "Verify"
                          )}
                        </Button>
                      </div>
                    </div>

                    {/* Instagram */}
                    <div className="space-y-1.5">
                      <Label
                        htmlFor="instagram"
                        className="text-[11px] font-bold uppercase tracking-wider text-ink-muted"
                      >
                        Instagram
                      </Label>
                      <div className="flex items-center gap-2">
                        <div className="flex items-center flex-1">
                          <span className="inline-flex items-center px-3 rounded-l-xl border border-r-0 border-hairline bg-ink-3 text-ink-muted text-xs h-11 font-mono">
                            ig.com/
                          </span>
                          <Input
                            id="instagram"
                            value={instagram}
                            onChange={(e) => {
                              setInstagram(cleanHandle(e.target.value, "instagram"));
                              setVerifiedHandles((prev) => ({ ...prev, instagram: false }));
                            }}
                            className="rounded-l-none rounded-r-xl h-11 bg-ink border-hairline text-xs font-mono text-ink-fg"
                            placeholder="username"
                          />
                        </div>
                        <Button
                          variant="ghost"
                          size="sm"
                          className={cn(
                            "h-11 rounded-xl font-bold px-3 transition-all cursor-pointer",
                            verifiedHandles["instagram"]
                              ? "bg-emerald-500/15 text-emerald-400 border border-emerald-500/30"
                              : "bg-gold/15 text-gold border border-gold/30 hover:bg-gold/25",
                          )}
                          disabled={
                            !instagram ||
                            !!getValidationError(instagram, "instagram") ||
                            verifyingHandles["instagram"] ||
                            verifiedHandles["instagram"]
                          }
                          onClick={() => handleManualVerify("instagram", instagram)}
                        >
                          {verifyingHandles["instagram"] ? (
                            <Loader2 className="size-4 animate-spin" />
                          ) : verifiedHandles["instagram"] ? (
                            <Check className="size-4" />
                          ) : (
                            "Verify"
                          )}
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex gap-3 pt-2">
                  <Button
                    variant="outline"
                    className="flex-1 rounded-xl font-bold h-11 border-hairline hover:bg-ink-3 text-xs cursor-pointer"
                    onClick={() => {
                      resetForm();
                      setIsEditing(false);
                    }}
                    disabled={updateProfile.isPending}
                  >
                    Cancel
                  </Button>
                  <Button
                    className="flex-[2] rounded-xl font-bold h-11 text-xs bg-gold text-ink hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10 font-black"
                    onClick={() => {
                      const combinedPhone = `${countryCode} ${phoneBody}`.trim();
                      const normalizedUsername = normalizeUsername(username);

                      if (normalizedUsername && normalizedUsername !== normalizeUsername(profile?.username || "")) {
                        if (usernameStatus.loading || usernameStatus.available === false || usernameStatus.error) {
                          toast.error("Please choose an available username before saving.");
                          return;
                        }
                      }

                      updateProfile.mutate({
                        full_name: fullName,
                        username: normalizedUsername,
                        avatar_url: avatarUrl,
                        phone_number: combinedPhone,
                        twitter_handle: twitter,
                        facebook_handle: facebook,
                        telegram_handle: telegram,
                        instagram_handle: instagram,
                      });
                    }}
                    disabled={updateProfile.isPending || usernameStatus.loading}
                  >
                    {updateProfile.isPending ? (
                      <span className="flex items-center gap-2">
                        <Loader2 className="size-4 animate-spin" /> Saving Changes...
                      </span>
                    ) : (
                      <span className="flex items-center gap-1.5">
                        <Check className="size-4" /> Save Profile Changes
                      </span>
                    )}
                  </Button>
                </div>
              </div>

              {/* Security / Password Card */}
              <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 sm:p-7 shadow-lg backdrop-blur-xl space-y-4">
                <div>
                  <h3 className="text-base font-black text-ink-fg">Account Security</h3>
                  <p className="text-xs text-ink-muted font-medium">Update your account password</p>
                </div>

                <form onSubmit={handlePasswordChange} className="space-y-4">
                  <div className="space-y-1.5">
                    <Label
                      htmlFor="new-password"
                      className="text-xs font-bold uppercase tracking-wider text-ink-muted"
                    >
                      New Password
                    </Label>
                    <div className="relative">
                      <Lock className="absolute left-3.5 top-3.5 size-4 text-ink-muted" />
                      <Input
                        id="new-password"
                        type={showNewPassword ? "text" : "password"}
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        className="pl-10 pr-10 rounded-xl h-11 bg-ink border-hairline text-ink-fg"
                        placeholder="Minimum 6 characters"
                      />
                      <button
                        type="button"
                        onClick={() => setShowNewPassword(!showNewPassword)}
                        className="absolute right-3.5 top-3.5 text-ink-muted hover:text-ink-fg transition-colors cursor-pointer"
                      >
                        {showNewPassword ? (
                          <EyeOff className="size-4" />
                        ) : (
                          <Eye className="size-4" />
                        )}
                      </button>
                    </div>
                  </div>
                  <Button
                    type="submit"
                    className="w-full rounded-xl font-bold h-11 text-xs bg-gold text-ink hover:bg-gold-soft cursor-pointer shadow-md shadow-gold/10"
                    disabled={isChangingPassword || !newPassword}
                  >
                    {isChangingPassword ? (
                      <span className="flex items-center gap-2">
                        <Loader2 className="size-4 animate-spin" /> Updating Password...
                      </span>
                    ) : (
                      <span>Update Password</span>
                    )}
                  </Button>
                </form>
              </div>
            </motion.div>
          ) : (
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              className="space-y-6"
            >
              {/* Special Role Management Gateway */}
              {hasSpecialRole && (
                <div className="rounded-3xl border border-gold/30 bg-gradient-to-br from-[#002d26] via-[#003830] to-[#011e19] p-6 text-white shadow-xl space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="text-[10px] font-black uppercase tracking-widest text-gold">
                        Internal Access
                      </span>
                      <h3 className="text-lg font-black text-white">
                        Platform Administration Portals
                      </h3>
                    </div>
                    <div className="size-10 rounded-2xl bg-gold/15 text-gold flex items-center justify-center border border-gold/30">
                      <Shield className="size-5" />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 gap-2.5 pt-1">
                    {isAdmin && (
                      <Link
                        to="/admin"
                        className="flex items-center justify-between p-3.5 bg-black/40 rounded-2xl border border-white/15 hover:border-gold/50 transition-all group cursor-pointer"
                      >
                        <div className="flex items-center gap-3">
                          <div className="size-9 rounded-xl bg-gold text-ink flex items-center justify-center font-bold group-hover:scale-105 transition-transform">
                            <LayoutDashboard className="size-4" />
                          </div>
                          <div>
                            <span className="text-xs font-bold text-white block">
                              Admin Master Console
                            </span>
                            <span className="text-[10px] text-white/60">
                              Manage tasks, rewards, and user submissions
                            </span>
                          </div>
                        </div>
                        <ArrowRight className="size-4 text-gold group-hover:translate-x-1 transition-transform" />
                      </Link>
                    )}

                    {isModerator && (
                      <Link
                        to="/moderator"
                        className="flex items-center justify-between p-3.5 bg-black/40 rounded-2xl border border-white/15 hover:border-gold/50 transition-all group cursor-pointer"
                      >
                        <div className="flex items-center gap-3">
                          <div className="size-9 rounded-xl bg-blue-500 text-white flex items-center justify-center font-bold group-hover:scale-105 transition-transform">
                            <Shield className="size-4" />
                          </div>
                          <div>
                            <span className="text-xs font-bold text-white block">
                              Moderator Tools
                            </span>
                            <span className="text-[10px] text-white/60">
                              Review and verify task submissions
                            </span>
                          </div>
                        </div>
                        <ArrowRight className="size-4 text-gold group-hover:translate-x-1 transition-transform" />
                      </Link>
                    )}

                    {isTasker && (
                      <Link
                        to="/tasker"
                        className="flex items-center justify-between p-3.5 bg-black/40 rounded-2xl border border-white/15 hover:border-gold/50 transition-all group cursor-pointer"
                      >
                        <div className="flex items-center gap-3">
                          <div className="size-9 rounded-xl bg-indigo-500 text-white flex items-center justify-center font-bold group-hover:scale-105 transition-transform">
                            <Shield className="size-4" />
                          </div>
                          <div>
                            <span className="text-xs font-bold text-white block">
                              Tasker Workspace
                            </span>
                            <span className="text-[10px] text-white/60">
                              Create and curate partner opportunities
                            </span>
                          </div>
                        </div>
                        <ArrowRight className="size-4 text-gold group-hover:translate-x-1 transition-transform" />
                      </Link>
                    )}
                  </div>
                </div>
              )}

              {/* Quick Action Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Link
                  to="/redeem"
                  className="rounded-3xl p-5 bg-ink-2/70 border border-hairline hover:border-gold/30 transition-all duration-300 shadow-md group flex items-center justify-between backdrop-blur-xl"
                >
                  <div className="flex items-center gap-3.5">
                    <div className="size-11 rounded-2xl bg-gold/15 border border-gold/30 text-gold flex items-center justify-center group-hover:scale-105 transition-transform">
                      <Gift className="size-5" />
                    </div>
                    <div>
                      <p className="text-xs font-black text-ink-fg">Redeem Rewards</p>
                      <p className="text-[11px] font-medium text-ink-muted">
                        Browse gift card catalog
                      </p>
                    </div>
                  </div>
                  <ArrowRight className="size-4 text-gold group-hover:translate-x-1 transition-transform" />
                </Link>

                <Link
                  to="/transactions"
                  className="rounded-3xl p-5 bg-ink-2/70 border border-hairline hover:border-gold/30 transition-all duration-300 shadow-md group flex items-center justify-between backdrop-blur-xl"
                >
                  <div className="flex items-center gap-3.5">
                    <div className="size-11 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 flex items-center justify-center group-hover:scale-105 transition-transform">
                      <HistoryIcon className="size-5" />
                    </div>
                    <div>
                      <p className="text-xs font-black text-ink-fg">Transaction Ledger</p>
                      <p className="text-[11px] font-medium text-ink-muted">
                        View past claims & credits
                      </p>
                    </div>
                  </div>
                  <ArrowRight className="size-4 text-emerald-400 group-hover:translate-x-1 transition-transform" />
                </Link>
              </div>

              {/* Verified Identity Ledger Cards */}
              <div className="rounded-3xl border border-hairline bg-ink-2/70 p-6 shadow-lg backdrop-blur-xl space-y-4">
                <div className="flex items-center justify-between border-b border-hairline pb-4">
                  <h3 className="text-base font-black text-ink-fg">Verified Channels & Details</h3>
                  <span className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                    Public Profile
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                  <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-center gap-3.5">
                    <div className="size-9 rounded-xl bg-blue-500/15 text-blue-400 flex items-center justify-center border border-blue-500/25 shrink-0">
                      <Mail className="size-4" />
                    </div>
                    <div className="overflow-hidden">
                      <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                        Email
                      </p>
                      <p className="text-xs font-bold text-ink-fg truncate">
                        {profile?.email || "N/A"}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-center gap-3.5">
                    <div className="size-9 rounded-xl bg-purple-500/15 text-purple-400 flex items-center justify-center border border-purple-500/25 shrink-0">
                      <Phone className="size-4" />
                    </div>
                    <div className="overflow-hidden">
                      <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                        Phone
                      </p>
                      <p className="text-xs font-bold text-ink-fg truncate font-mono">
                        {profile?.phone_number || "Not added"}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-center gap-3.5">
                    <div className="size-9 rounded-xl bg-sky-500/15 text-sky-400 flex items-center justify-center border border-sky-500/25 shrink-0">
                      <Share2 className="size-4" />
                    </div>
                    <div className="overflow-hidden">
                      <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                        Twitter / X
                      </p>
                      <p className="text-xs font-bold text-ink-fg truncate font-mono">
                        {profile?.twitter_handle ? `@${profile.twitter_handle}` : "Not linked"}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-center gap-3.5">
                    <div className="size-9 rounded-xl bg-blue-500/15 text-blue-400 flex items-center justify-center border border-blue-500/25 shrink-0">
                      <Globe className="size-4" />
                    </div>
                    <div className="overflow-hidden">
                      <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                        Telegram
                      </p>
                      <p className="text-xs font-bold text-ink-fg truncate font-mono">
                        {profile?.telegram_handle ? `@${profile.telegram_handle}` : "Not linked"}
                      </p>
                    </div>
                  </div>

                  <div className="rounded-2xl p-4 bg-ink border border-hairline flex items-center gap-3.5 sm:col-span-2">
                    <div className="size-9 rounded-xl bg-emerald-500/15 text-emerald-400 flex items-center justify-center border border-emerald-500/25 shrink-0">
                      <Calendar className="size-4" />
                    </div>
                    <div className="overflow-hidden">
                      <p className="text-[10px] font-bold text-ink-muted uppercase tracking-wider">
                        Member Since
                      </p>
                      <p className="text-xs font-bold text-ink-fg">
                        {profile?.created_at
                          ? new Date(profile.created_at).toLocaleDateString(undefined, {
                              month: "long",
                              day: "numeric",
                              year: "numeric",
                            })
                          : "N/A"}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}

export default ProfilePage;
