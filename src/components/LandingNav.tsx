import { useState, useEffect } from "react";
import { Link } from "@tanstack/react-router";
import { ArrowRight, Menu, X } from "lucide-react";
import { ThemeToggle } from "@/components/ThemeToggle";
import { cn } from "@/lib/utils";

const NAV_LINKS = [
  { label: "Opportunities", href: "/#opportunities" },
  { label: "How It Works", href: "/#how-it-works" },
  { label: "Benefits", href: "/#benefits" },
  { label: "About", href: "/about" },
  { label: "FAQ", href: "/#faq" },
];

export function LandingNav() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 12);
    handleScroll();
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [mobileOpen]);

  return (
    <header className="fixed inset-x-0 top-0 z-50 px-3 pt-3 sm:px-6 sm:pt-4">
      <div className="relative mx-auto max-w-6xl rgb-neon-wrapper transition-all duration-300">
        <div
          className={cn(
            "rgb-neon-inner grid h-14 grid-cols-[minmax(0,1fr)_auto] items-center gap-4 px-3 transition-all duration-300 sm:h-16 sm:px-5 lg:grid-cols-[auto_1fr_auto]",
            scrolled
              ? "ink-header-shadow border border-hairline bg-ink"
              : "border border-hairline/60 bg-ink shadow-[0_10px_30px_-20px_rgba(0,0,0,0.55)]",
          )}
        >
          <Link to="/" className="flex min-w-0 items-center gap-2.5">
            <img src="/logo.png" alt="Noble Gain" className="h-8 w-8 shrink-0 object-contain" />
            <span className="truncate text-[17px] font-black tracking-[-0.03em] text-ink-fg">
              Noble<span className="text-gold">Gain</span>
            </span>
          </Link>

          <nav className="hidden items-center justify-center gap-8 lg:flex">
            {NAV_LINKS.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="text-[13px] font-semibold tracking-tight text-ink-muted transition-colors hover:text-ink-fg"
              >
                {link.label}
              </a>
            ))}
          </nav>

          <div className="flex items-center justify-end gap-2 sm:gap-3">
            <span className="text-ink-fg">
              <ThemeToggle />
            </span>
            <Link
              to="/auth"
              className="hidden text-[13px] font-semibold text-ink-muted transition-colors hover:text-ink-fg sm:block"
            >
              Sign In
            </Link>
            <Link
              to="/auth"
              search={{ mode: "signup" }}
              className="group inline-flex h-10 items-center gap-1.5 rounded-xl bg-gold px-4 text-[13px] font-bold tracking-tight text-ink transition-transform duration-200 hover:-translate-y-0.5"
            >
              Get Started
              <ArrowRight className="size-3.5 transition-transform duration-200 group-hover:translate-x-0.5" />
            </Link>
            <button
              type="button"
              aria-label="Open menu"
              onClick={() => setMobileOpen(true)}
              className="grid size-10 place-items-center rounded-xl border border-hairline text-ink-fg lg:hidden cursor-pointer"
            >
              <Menu className="size-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Menu Drawer */}
      <div
        className={cn(
          "fixed inset-0 z-50 lg:hidden",
          mobileOpen ? "pointer-events-auto" : "pointer-events-none",
        )}
      >
        <div
          onClick={() => setMobileOpen(false)}
          className={cn(
            "absolute inset-0 bg-ink/80 backdrop-blur-sm transition-opacity duration-300",
            mobileOpen ? "opacity-100" : "opacity-0",
          )}
        />
        <div
          className={cn(
            "absolute inset-x-3 top-3 rounded-2xl border border-hairline bg-ink-2 p-5 transition-all duration-300",
            mobileOpen ? "translate-y-0 opacity-100" : "-translate-y-3 opacity-0",
          )}
        >
          <div className="flex items-center justify-between">
            <span className="text-base font-black tracking-[-0.03em] text-ink-fg">
              Noble<span className="text-gold">Gain</span>
            </span>
            <span className="ml-auto mr-2 text-ink-fg">
              <ThemeToggle />
            </span>
            <button
              type="button"
              aria-label="Close menu"
              onClick={() => setMobileOpen(false)}
              className="grid size-9 place-items-center rounded-xl border border-hairline text-ink-fg cursor-pointer"
            >
              <X className="size-4" />
            </button>
          </div>

          <nav className="mt-6 flex flex-col">
            {NAV_LINKS.map((link) => (
              <a
                key={link.href}
                href={link.href}
                onClick={() => setMobileOpen(false)}
                className="border-b border-hairline py-3.5 text-base font-semibold tracking-tight text-ink-fg/85"
              >
                {link.label}
              </a>
            ))}
          </nav>

          <div className="mt-6 grid gap-2.5">
            <Link
              to="/auth"
              search={{ mode: "signup" }}
              onClick={() => setMobileOpen(false)}
              className="grid h-12 place-items-center rounded-xl bg-gold text-sm font-bold text-ink"
            >
              Get Started
            </Link>
            <Link
              to="/auth"
              onClick={() => setMobileOpen(false)}
              className="grid h-12 place-items-center rounded-xl border border-hairline text-sm font-semibold text-ink-fg"
            >
              Sign In
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}
