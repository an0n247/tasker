import { Link } from "@tanstack/react-router";
import { ShieldCheck } from "lucide-react";

export function PublicFooter() {
  return (
    <footer className="border-t border-hairline px-4 py-12 sm:px-6 md:py-16 bg-ink text-ink-fg">
      <div className="mx-auto max-w-6xl">
        <div className="grid gap-10 md:grid-cols-[1.3fr_repeat(3,minmax(0,1fr))]">
          <div className="max-w-xs">
            <Link to="/" className="flex items-center gap-2.5">
              <img src="/logo.png" alt="Noble Gain" className="h-7 w-7 shrink-0 object-contain" />
              <span className="text-base font-black tracking-[-0.03em] text-ink-fg">
                Noble<span className="text-gold">Gain</span>
              </span>
            </Link>
            <p className="mt-4 text-sm leading-6 text-ink-muted">
              Complete opportunities, earn rewards and track your progress from one simple platform.
            </p>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-ink-fg/70">
              Platform
            </p>
            <ul className="mt-4 space-y-2.5 text-sm text-ink-muted">
              <li>
                <a href="/#opportunities" className="hover:text-ink-fg">
                  Opportunities
                </a>
              </li>
              <li>
                <a href="/#how-it-works" className="hover:text-ink-fg">
                  How it works
                </a>
              </li>
              <li>
                <a href="/#benefits" className="hover:text-ink-fg">
                  Benefits
                </a>
              </li>
              <li>
                <Link to="/auth" className="hover:text-ink-fg">
                  Sign in
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-ink-fg/70">
              Company
            </p>
            <ul className="mt-4 space-y-2.5 text-sm text-ink-muted">
              <li>
                <Link to="/about" className="hover:text-ink-fg">
                  About
                </Link>
              </li>
              <li>
                <a href="/#faq" className="hover:text-ink-fg">
                  FAQ
                </a>
              </li>
              <li>
                <Link to="/auth" search={{ mode: "signup" }} className="hover:text-ink-fg">
                  Get started
                </Link>
              </li>
            </ul>
          </div>

          <div>
            <p className="text-[11px] font-bold uppercase tracking-[0.18em] text-ink-fg/70">
              Legal & support
            </p>
            <ul className="mt-4 space-y-2.5 text-sm text-ink-muted">
              <li>
                <Link to="/privacy" className="hover:text-ink-fg">
                  Privacy policy
                </Link>
              </li>
              <li>
                <Link to="/terms" className="hover:text-ink-fg">
                  Terms of service
                </Link>
              </li>
              <li>
                <Link to="/about" className="hover:text-ink-fg">
                  Contact
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="mt-12 flex flex-col gap-3 border-t border-hairline pt-6 text-xs text-ink-muted sm:flex-row sm:items-center sm:justify-between">
          <span>© {new Date().getFullYear()} Noble Gain. All rights reserved.</span>
          <span className="flex items-center gap-2">
            <ShieldCheck className="size-3.5 text-gold" /> Secure account management
          </span>
        </div>
      </div>
    </footer>
  );
}
