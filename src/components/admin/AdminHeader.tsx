import { Link, useRouter } from "@tanstack/react-router";
import { ArrowLeft, Shield, LogOut, User, Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ThemeToggle } from "@/components/ThemeToggle";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { supabase } from "@/integrations/supabase/client";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";

interface AdminHeaderProps {
  roleTitle?: string;
}

export function AdminHeader({ roleTitle = "Super Admin" }: AdminHeaderProps) {
  const router = useRouter();

  const { data: profile } = useQuery({
    queryKey: ["current-admin-profile"],
    queryFn: async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return null;

      const { data } = await supabase
        .from("profiles")
        .select("id, full_name, username, email, avatar_url")
        .eq("id", user.id)
        .maybeSingle();

      return data || { id: user.id, email: user.email };
    },
  });

  const handleSignOut = async () => {
    try {
      await supabase.auth.signOut();
      toast.success("Signed out successfully");
      router.navigate({ to: "/auth" });
    } catch (err: any) {
      toast.error("Failed to sign out: " + err.message);
    }
  };

  const displayName = profile?.full_name || profile?.username || profile?.email || "Admin";
  const initials = displayName
    .split(" ")
    .map((n: string) => n[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border/50 bg-background/85 backdrop-blur-xl shadow-xs transition-colors">
      <div className="w-full max-w-[1600px] mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
        {/* Left: Brand & Console Identity */}
        <div className="flex items-center gap-3">
          <Link
            to="/admin"
            className="flex items-center gap-2.5 transition-transform hover:scale-102 active:scale-98"
          >
            <img src="/logo.png" alt="Noble Gain" className="size-8 object-contain" />
            <div className="flex flex-col">
              <div className="flex items-center gap-1.5 font-black text-base tracking-tight text-foreground">
                <span>Noble Gain</span>
                <Badge
                  variant="secondary"
                  className="text-[9px] font-black uppercase tracking-wider px-1.5 py-0 bg-primary/10 text-primary border-primary/20"
                >
                  Console
                </Badge>
              </div>
            </div>
          </Link>

          <div className="hidden sm:flex items-center gap-2 pl-3 border-l border-border/60">
            <div className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-[10px] font-black text-emerald-600 dark:text-emerald-400 uppercase tracking-wider">
              <div className="size-1.5 rounded-full bg-emerald-500 animate-pulse" />
              <span>{roleTitle}</span>
            </div>
          </div>
        </div>

        {/* Right: Actions, Theme, Return to App & User Menu */}
        <div className="flex items-center gap-2 sm:gap-3">
          {/* Quick Exit to User App */}
          <Link to="/dashboard">
            <Button
              variant="outline"
              size="sm"
              className="h-9 px-3 rounded-xl font-bold text-xs gap-1.5 border-border/60 hover:bg-accent/10 transition-colors shadow-2xs"
            >
              <ArrowLeft className="size-3.5" />
              <span className="hidden sm:inline">Exit to User App</span>
              <span className="sm:hidden">App</span>
            </Button>
          </Link>

          {/* Dark / Light Mode Switcher */}
          <ThemeToggle />

          {/* Admin User Profile Dropdown */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                className="flex items-center gap-2 p-1 rounded-xl hover:bg-accent/10 transition-colors cursor-pointer focus:outline-none"
                title="Admin Account"
              >
                <Avatar className="size-8 border border-border/60">
                  <AvatarImage src={profile?.avatar_url || ""} />
                  <AvatarFallback className="bg-primary/10 text-primary font-bold text-xs">
                    {initials || "AD"}
                  </AvatarFallback>
                </Avatar>
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56 rounded-2xl border-border/60 p-1.5">
              <DropdownMenuLabel className="font-normal px-2 py-1.5">
                <div className="text-xs font-bold text-foreground truncate">{displayName}</div>
                <div className="text-[11px] text-muted-foreground truncate">{profile?.email}</div>
                <div className="mt-1 flex items-center gap-1 text-[9px] font-black uppercase tracking-wider text-primary">
                  <Shield className="size-3" />
                  <span>{roleTitle}</span>
                </div>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem asChild>
                <Link
                  to="/dashboard"
                  className="flex items-center gap-2 text-xs font-semibold px-2 py-1.5 rounded-lg cursor-pointer"
                >
                  <ArrowLeft className="size-3.5" />
                  <span>Return to User Dashboard</span>
                </Link>
              </DropdownMenuItem>
              <DropdownMenuItem asChild>
                <Link
                  to="/profile"
                  className="flex items-center gap-2 text-xs font-semibold px-2 py-1.5 rounded-lg cursor-pointer"
                >
                  <User className="size-3.5" />
                  <span>My Profile</span>
                </Link>
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem
                onClick={handleSignOut}
                className="flex items-center gap-2 text-xs font-semibold px-2 py-1.5 rounded-lg text-destructive focus:text-destructive focus:bg-destructive/10 cursor-pointer"
              >
                <LogOut className="size-3.5" />
                <span>Sign Out</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  );
}
