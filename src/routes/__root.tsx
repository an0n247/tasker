import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { cn } from "@/lib/utils";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
  useLocation,
} from "@tanstack/react-router";
import { useEffect, type ReactNode } from "react";
import { SpeedInsights } from "@vercel/speed-insights/react";

import appCss from "../styles.css?url";
import { reportLovableError } from "../lib/lovable-error-reporting";
import { Navigation } from "@/components/Navigation";
import { MobileTabBar } from "@/components/MobileTabBar";
import { Coins } from "lucide-react";
import { Toaster } from "@/components/ui/sonner";
import { Onboarding } from "@/components/Onboarding";
import { ThemeProvider } from "@/hooks/use-theme";
import { supabase } from "@/integrations/supabase/client";
import { ensureBucketsExist } from "@/utils/storage-init";
import { VideoAdInterstitial } from "@/components/VideoAdInterstitial";
import { recordClientSession } from "@/lib/session-tracking.functions";

function NotFoundComponent() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="flex flex-col items-center text-center max-w-md">
        <img
          src="/logo.png"
          alt="Noble Gain"
          className="h-24 w-24 object-contain animate-pulse mb-8"
        />

        <h1 className="text-8xl font-black text-primary tracking-tighter mb-2">404</h1>
        <h2 className="text-2xl font-black uppercase tracking-tight text-foreground mb-4">
          Lost in the vault?
        </h2>
        <p className="text-muted-foreground font-medium mb-10 leading-relaxed">
          The page you're looking for doesn't exist or has been moved to another section of the
          platform.
        </p>

        <Link
          to="/"
          className="group relative inline-flex items-center justify-center gap-2 rounded-2xl bg-primary px-8 py-4 text-sm font-black uppercase tracking-widest text-primary-foreground transition-all hover:scale-105 active:scale-95 shadow-lg shadow-primary/25"
        >
          Back to Dashboard
          <div className="absolute inset-0 rounded-2xl bg-white/10 opacity-0 transition-opacity group-hover:opacity-100" />
        </Link>

        <div className="mt-12 flex items-center gap-2 font-black text-xs text-muted-foreground/40 uppercase tracking-[0.2em]">
          <span>Noble Gain</span>
          <span className="h-1 w-1 rounded-full bg-muted-foreground/20" />
          <span>Security Protocol</span>
        </div>
      </div>
    </div>
  );
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  console.error(error);
  const router = useRouter();
  useEffect(() => {
    reportLovableError(error, { boundary: "tanstack_root_error_component" });
  }, [error]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="flex flex-col items-center animate-pulse">
        <img src="/logo.png" alt="Noble Gain" className="h-20 w-20 object-contain mb-4" />
        <div className="flex items-center gap-2 font-black text-2xl tracking-tighter uppercase">
          <span className="text-foreground">
            Noble <span className="text-[#e6c17a]">Gain</span>
          </span>
        </div>
        <p className="mt-4 text-sm font-bold text-muted-foreground uppercase tracking-widest">
          Loading your experience...
        </p>
        <div className="mt-8 flex gap-3">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="text-xs font-black uppercase tracking-widest text-primary hover:underline"
          >
            Try Again
          </button>
          <span className="text-muted-foreground/30">|</span>
          <a
            href="/"
            className="text-xs font-black uppercase tracking-widest text-muted-foreground hover:text-foreground"
          >
            Go Home
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  beforeLoad: async () => {
    // Domain redirects disabled - site works independently on all URLs
  },
  head: () => {
    const url = typeof window !== "undefined" ? window.location.origin : "https://noblegain.bytsphere.buzz";
    const canonicalUrl = typeof window !== "undefined" ? `${url}${window.location.pathname}` : url;

    return {
      meta: [
        { charSet: "utf-8" },
        {
          name: "viewport",
          content: "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no",
        },
        { title: "Noble Gain — Reward Your Time" },
        {
          name: "description",
          content:
            "The ultimate rewards platform. Earn points for simple tasks, refer friends, and redeem for amazing prizes.",
        },
        { name: "author", content: "Noble Gain" },
        { property: "og:title", content: "Noble Gain — Reward Your Time" },
        {
          property: "og:description",
          content:
            "The ultimate rewards platform. Earn points for simple tasks, refer friends, and redeem for amazing prizes.",
        },
        { property: "og:type", content: "website" },
        { property: "og:url", content: canonicalUrl },
        { property: "og:image", content: `${url}/logo.png` },
        { name: "twitter:card", content: "summary_large_image" },
        { name: "twitter:site", content: "@NobleGain" },
        { name: "6a97888e-site-verification", content: "2a365eac71037194b13cbbf9bee6c208" },
      ],
      links: [
        { rel: "canonical", href: canonicalUrl },
        {
          rel: "stylesheet",
          href: appCss,
        },
        {
          rel: "stylesheet",
          href: "https://fonts.googleapis.com/css2?family=Urbanist:ital,wght@0,300;0,400;0,500;0,600;0,700;1,300;1,400;1,500&family=Plus+Jakarta+Sans:ital,wght@0,300;0,400;0,500;0,600;1,300;1,400&display=swap",
        },
        { rel: "icon", href: "/logo.png", type: "image/png" },
        { rel: "apple-touch-icon", href: "/logo.png" },
      ],
      scripts: [
        {
          type: "application/ld+json",
          children: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "Organization",
            name: "Noble Gain",
            url: url,
            logo: `${url}/logo.png`,
            description:
              "The ultimate rewards platform. Earn points for simple tasks, refer friends, and redeem for amazing prizes.",
          }),
        },
        {
          type: "application/ld+json",
          children: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "WebSite",
            name: "Noble Gain",
            url: url,
            potentialAction: {
              "@type": "SearchAction",
              target: `${url}/search?q={search_term_string}`,
              "query-input": "required name=search_term_string",
            },
          }),
        },
      ],
    };
  },
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootShell({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <SpeedInsights />
        <Scripts />
      </body>
    </html>
  );
}

function RootComponent() {
  const location = useLocation();
  const router = useRouter();
  const publicRoutes = ["/", "/landing", "/about", "/privacy", "/terms"];
  const isPublicPage = publicRoutes.includes(location.pathname);
  const isAuthPage = location.pathname.startsWith("/auth");
  const { queryClient } = Route.useRouteContext();

  useEffect(() => {
    if (typeof window === "undefined") return;

    // Generate simple fingerprint for basic fraud detection
    if (!(window as any)._ep_fingerprint) {
      const fp = [
        window.navigator.userAgent,
        window.screen.width,
        window.screen.height,
        new Date().getTimezoneOffset(),
        window.navigator.language,
      ].join("|");

      let hash = 0;
      for (let i = 0; i < fp.length; i++) {
        const char = fp.charCodeAt(i);
        hash = (hash << 5) - hash + char;
        hash = hash & hash;
      }
      (window as any)._ep_fingerprint = Math.abs(hash).toString(16);
    }

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (event, session) => {
      console.log("Auth state change in root:", event, session?.user?.id);

      if (session?.user) {
        // Record login IP/fingerprint. The IP is resolved server-side from the
        // request headers so it is a real address, never a client-supplied value.
        recordClientSession({
          data: { fingerprint: (window as any)._ep_fingerprint ?? null },
        }).catch((err) => console.error("Failed to record session:", err));
      }

      if (event !== "SIGNED_IN" && event !== "SIGNED_OUT" && event !== "USER_UPDATED") return;

      router.invalidate();

      if (event === "SIGNED_OUT") {
        const currentPath = window.location.pathname;
        const publicPages = ["/", "/auth", "/landing", "/about", "/privacy", "/terms"];
        if (!publicPages.includes(currentPath)) {
          router.navigate({ to: "/auth" });
        }
      }
    });

    // Clean up flags from the previous transient-session implementation.
    localStorage.removeItem("noble-gain-session-transient");
    sessionStorage.removeItem("noble-gain-session-active");

    return () => subscription.unsubscribe();
  }, [router]);

  useEffect(() => {
    ensureBucketsExist().catch((err) => console.error("Bucket init failed:", err));
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const params = new URLSearchParams(window.location.search);
    const refCode = params.get("ref");

    if (refCode) {
      const trackClick = async () => {
        const { error } = await supabase.rpc("increment_referral_clicks", {
          target_referral_code: refCode,
        });
        if (error) console.error("Error tracking referral click:", error);
      };
      trackClick();
    }
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider defaultTheme="light" storageKey="noble-gain-theme">
        <div
          className={cn(
            "flex min-h-screen relative w-full max-w-full flex-col",
            !isAuthPage && !isPublicPage && "bg-background text-foreground",
          )}
        >
          {!isAuthPage && !isPublicPage && <Navigation />}
          {!isAuthPage && !isPublicPage && <MobileTabBar />}
          <main
            className={cn(
              "flex-1 transition-all duration-300 w-full flex flex-col",
              !isPublicPage &&
                !isAuthPage &&
                "md:ml-[var(--app-sidebar-w)] w-full md:w-[calc(100%-var(--app-sidebar-w))] pb-20 md:pb-0",
            )}
          >
            <div
              className={cn(
                "flex-1 w-full",
                !isPublicPage &&
                  !isAuthPage &&
                  "pt-24 md:pt-28 pb-12 px-4 md:px-8 max-w-7xl mx-auto",
              )}
            >
              <Outlet />
            </div>
          </main>
        </div>
        <Toaster />
        <Onboarding />
        <VideoAdInterstitial />
      </ThemeProvider>
    </QueryClientProvider>
  );
}
