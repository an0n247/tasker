import { Link, useLocation } from "@tanstack/react-router";
import { LayoutDashboard, Coins, Gift, Share2, User } from "lucide-react";
import { cn } from "@/lib/utils";

export function MobileTabBar() {
  const location = useLocation();
  const currentPath = location.pathname;

  const tabs = [
    { name: "Home", href: "/dashboard", icon: LayoutDashboard },
    { name: "Earn", href: "/earn", icon: Coins },
    { name: "Redeem", href: "/redeem", icon: Gift },
    { name: "Refer", href: "/refer", icon: Share2 },
    { name: "Profile", href: "/profile", icon: User },
  ];

  return (
    <div className="md:hidden fixed bottom-4 left-4 right-4 z-[60] animate-in fade-in slide-in-from-bottom-4 duration-500">
      <nav className="relative flex items-center justify-around bg-ink/90 backdrop-blur-xl border border-hairline shadow-2xl rounded-2xl px-2 py-2">
        {tabs.map((tab) => {
          const isActive = currentPath === tab.href;
          return (
            <Link
              key={tab.name}
              to={tab.href as any}
              className={cn(
                "relative flex flex-col items-center gap-1 transition-all duration-300 px-3 py-1.5 rounded-xl",
                isActive ? "text-gold font-bold bg-gold/10" : "text-ink-muted hover:text-ink-fg",
              )}
            >
              <tab.icon
                className={cn(
                  "h-4.5 w-4.5 transition-all duration-300",
                  isActive ? "fill-gold/20 stroke-[2.5px] text-gold" : "stroke-[2px]",
                )}
              />
              <span
                className={cn(
                  "text-[9px] font-black uppercase tracking-wider transition-all duration-300",
                  isActive ? "opacity-100" : "opacity-0 h-0 w-0 scale-0",
                )}
              >
                {tab.name}
              </span>

              {isActive && (
                <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1.5 h-0.5 rounded-full bg-gold shadow-[0_0_6px_rgba(230,193,122,0.9)]" />
              )}
            </Link>
          );
        })}
      </nav>
    </div>
  );
}
