import { createFileRoute, redirect, Link } from "@tanstack/react-router";
import { supabase } from "@/integrations/supabase/client";
import {
  ArrowRight,
  ArrowUpRight,
  CircleCheck,
  ShieldCheck,
  Wallet,
  CirclePlay,
  Share2,
  Gift,
  Compass,
  ChartColumn,
  ChartLine,
  Lock,
  Clock3,
  Sparkles,
} from "lucide-react";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { motion } from "framer-motion";
import { LandingNav } from "@/components/LandingNav";
import { z } from "zod";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/")({
  head: () => ({
    title: "Noble Gain — Reward Your Time",
    meta: [
      {
        name: "description",
        content:
          "Noble Gain turns your available time into rewards. Complete simple opportunities, track every point you earn, and redeem your balance for real rewards.",
      },
      {
        property: "og:title",
        content: "Noble Gain | Complete Opportunities, Earn Real Rewards",
      },
      {
        property: "og:description",
        content:
          "Discover opportunities, complete them, and watch your points grow. Transparent tracking, secure accounts and simple reward redemption.",
      },
      { property: "og:image", content: "/logo.png" },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  validateSearch: (search) => z.object({ ref: z.string().optional() }).parse(search),
  beforeLoad: async ({ search }) => {
    if (search.ref) throw redirect({ to: "/auth", search: { mode: "signup", ref: search.ref } });
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (session) throw redirect({ to: "/dashboard" });
  },
  component: LandingPage,
});

/* -------------------------------------------------------------------------- */
/*                                MOCK WINDOWS                                */
/* -------------------------------------------------------------------------- */

function MockWindow({
  title,
  children,
  className = "",
}: {
  title: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "mock-sheen overflow-hidden rounded-2xl border border-hairline bg-ink-2/90 shadow-[0_30px_60px_-40px_rgba(0,0,0,0.6)]",
        className,
      )}
    >
      <div className="flex items-center gap-2 border-b border-hairline px-4 py-3">
        <span className="mock-ping size-2 rounded-full bg-gold/70" />
        <span className="size-2 rounded-full bg-ink-fg/20" />
        <span className="size-2 rounded-full bg-ink-fg/20" />
        <span className="ml-2 text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-muted">
          {title}
        </span>
      </div>
      <div className="p-4 sm:p-5">{children}</div>
    </div>
  );
}

function MockBar({ value, delay }: { value: number; delay: number }) {
  return (
    <div className="flex h-full w-full items-end">
      <div
        className="mock-bar w-full rounded-t-[4px] bg-gradient-to-t from-gold/30 to-gold/85"
        style={{ height: `${value}%`, animationDelay: `${delay * 0.14}s` }}
      />
    </div>
  );
}

function DashboardMockup({ className = "" }: { className?: string }) {
  return (
    <MockWindow title="Dashboard" className={className}>
      <div className="grid gap-3 sm:grid-cols-[1.15fr_1fr]">
        <div className="rounded-xl border border-hairline bg-ink/60 p-4">
          <div className="flex items-start justify-between gap-3">
            <div className="min-w-0">
              <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-muted">
                Points balance
              </p>
              <p className="mock-count mt-2 text-3xl font-black tracking-[-0.04em] text-ink-fg sm:text-4xl">
                12,480
              </p>
            </div>
            <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-gold/12 text-gold">
              <Wallet className="size-4" />
            </span>
          </div>
          <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-ink-fg/10">
            <div
              className="mock-fill h-full rounded-full bg-gold"
              style={{ "--fill": "68%" } as React.CSSProperties}
            />
          </div>
          <div className="mt-2 flex justify-between text-[11px] font-medium text-ink-muted">
            <span>Next reward tier</span>
            <span className="text-ink-fg/80">68%</span>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-2">
            <div className="rounded-lg border border-hairline p-3">
              <p className="text-[11px] font-medium text-ink-muted">Today</p>
              <p className="mt-1 text-base font-black text-ink-fg">4 / 10 tasks</p>
            </div>
            <div className="rounded-lg border border-hairline p-3">
              <p className="text-[11px] font-medium text-ink-muted">Streak</p>
              <p className="mt-1 text-base font-black text-ink-fg">7 days</p>
            </div>
          </div>
        </div>
        <div className="rounded-xl border border-hairline bg-ink/60 p-4">
          <p className="text-[11px] font-semibold uppercase tracking-[0.16em] text-ink-muted">
            Recent activity
          </p>
          <ul className="mt-3 space-y-2.5">
            {[
              { icon: CirclePlay, label: "Watch & earn", value: "+40" },
              { icon: Share2, label: "Referral bonus", value: "+75" },
              { icon: CircleCheck, label: "Task verified", value: "+120" },
              { icon: Gift, label: "Reward redeemed", value: "-2,500" },
            ].map((item, index) => (
              <li
                key={item.label}
                className="mock-row-in flex items-center gap-2.5"
                style={{ animationDelay: `${index * 0.12}s` }}
              >
                <span className="grid size-7 shrink-0 place-items-center rounded-md bg-ink-fg/6 text-gold">
                  <item.icon className="size-3.5" />
                </span>
                <span className="min-w-0 flex-1 truncate text-xs font-medium text-ink-fg/85">
                  {item.label}
                </span>
                <span
                  className={cn(
                    "shrink-0 text-xs font-bold",
                    item.value.startsWith("-") ? "text-ink-muted" : "text-gold",
                  )}
                >
                  {item.value}
                </span>
              </li>
            ))}
          </ul>
          <div className="mt-4 flex h-16 items-end gap-1.5">
            {[38, 55, 44, 72, 60, 84, 68].map((val, idx) => (
              <MockBar key={idx} value={val} delay={idx} />
            ))}
          </div>
        </div>
      </div>
    </MockWindow>
  );
}

function OpportunitiesMockup() {
  return (
    <MockWindow title="Opportunities">
      <ul className="space-y-2.5">
        {[
          { title: "Watch a short video", meta: "Videos · instant", pts: "+40" },
          { title: "Follow on social", meta: "Social · review required", pts: "+60" },
          { title: "Daily check-in", meta: "Daily · repeatable", pts: "+20" },
          { title: "Invite a friend", meta: "Referral · on completion", pts: "+75" },
        ].map((item, index) => (
          <li
            key={item.title}
            style={{ animationDelay: `${index * 0.12}s` }}
            className="mock-row-in group flex items-center gap-3 rounded-xl border border-hairline p-3 transition-colors hover:border-gold/30"
          >
            <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-gold/10 text-gold">
              <ArrowUpRight className="size-4" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold tracking-tight text-ink-fg">{item.title}</p>
              <p className="truncate text-[11px] font-medium text-ink-muted">{item.meta}</p>
            </div>
            <span className="shrink-0 rounded-md bg-ink-fg/6 px-2 py-1 text-[11px] font-bold text-gold">
              {item.pts}
            </span>
          </li>
        ))}
      </ul>
    </MockWindow>
  );
}

function ActivityMockup() {
  return (
    <MockWindow title="Activity">
      <ul className="divide-y divide-[color:var(--hairline)]">
        {[
          { label: "Task verified", status: "Verified", icon: CircleCheck },
          { label: "Submission under review", status: "Pending", icon: Clock3 },
          { label: "Referral credited", status: "Completed", icon: Share2 },
          { label: "Reward request sent", status: "Processing", icon: Gift },
        ].map((item, index) => (
          <li
            key={item.label}
            style={{ animationDelay: `${index * 0.12}s` }}
            className="mock-row-in flex items-center gap-3 py-3 first:pt-0 last:pb-0"
          >
            <span className="grid size-7 shrink-0 place-items-center rounded-md bg-ink-fg/6 text-gold">
              <item.icon className="size-3.5" />
            </span>
            <span className="min-w-0 flex-1 truncate text-xs font-medium text-ink-fg/85">
              {item.label}
            </span>
            <span className="shrink-0 rounded-full border border-hairline px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider text-ink-muted">
              {item.status}
            </span>
          </li>
        ))}
      </ul>
    </MockWindow>
  );
}

function RewardsMockup() {
  return (
    <MockWindow title="Rewards">
      <div className="rounded-xl border border-hairline p-4">
        <div className="flex items-center justify-between gap-3">
          <div className="min-w-0">
            <p className="truncate text-sm font-bold tracking-tight text-ink-fg">
              Gift card reward
            </p>
            <p className="text-[11px] font-medium text-ink-muted">Costs 2,500 points</p>
          </div>
          <span className="shrink-0 rounded-lg bg-gold px-3 py-1.5 text-[11px] font-bold text-ink">
            Redeem
          </span>
        </div>
        <div className="mt-4 h-1.5 overflow-hidden rounded-full bg-ink-fg/10">
          <div
            className="mock-fill h-full rounded-full bg-gold"
            style={{ "--fill": "82%" } as React.CSSProperties}
          />
        </div>
        <p className="mt-2 text-[11px] font-medium text-ink-muted">
          2,050 of 2,500 points collected
        </p>
      </div>
      <div className="mt-3 grid grid-cols-3 gap-2">
        {["Requested", "Approved", "Fulfilled"].map((item, idx) => (
          <div key={item} className="rounded-lg border border-hairline p-2.5 text-center">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-ink-muted">
              {item}
            </p>
            <p
              className={cn("mt-1 text-xs font-black", idx === 0 ? "text-gold" : "text-ink-fg/50")}
            >
              {idx === 0 ? "Now" : "—"}
            </p>
          </div>
        ))}
      </div>
    </MockWindow>
  );
}

/* -------------------------------------------------------------------------- */
/*                               SHARED HELPERS                               */
/* -------------------------------------------------------------------------- */

const fadeVariants = {
  hidden: { opacity: 0, y: 18 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.5, ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number] },
  },
};

function FadeIn({
  children,
  className = "",
  delay = 0,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}) {
  return (
    <motion.div
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, amount: 0.15 }}
      variants={fadeVariants}
      transition={{ delay }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

function SectionEyebrow({ children }: { children: React.ReactNode }) {
  return <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-gold">{children}</p>;
}

function SectionWrapper({
  id,
  children,
  className = "",
}: {
  id?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section id={id} className={cn("scroll-mt-24 px-4 py-16 sm:px-6 md:py-28", className)}>
      <div className="mx-auto max-w-6xl">{children}</div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */
/*                               PAGE SECTIONS                                */
/* -------------------------------------------------------------------------- */

function HeroSection() {
  return (
    <section className="relative isolate overflow-hidden px-4 pb-16 pt-28 sm:px-6 md:pb-24 md:pt-36">
      <div className="pointer-events-none absolute inset-0 -z-10 ink-dots opacity-40 [mask-image:linear-gradient(to_bottom,black,transparent_75%)]" />
      <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 size-[34rem] -translate-x-1/2 rounded-full bg-gold/10 blur-[120px] ink-breathe" />

      <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-[1fr_0.95fr] lg:gap-16">
        <motion.div
          initial={{ opacity: 0, y: 22 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{
            duration: 0.6,
            ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number],
          }}
          className="max-w-2xl"
        >
          <div className="inline-flex items-center gap-2 rounded-full border border-hairline bg-ink-2/70 px-3.5 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-gold">
            <Sparkles className="size-3.5" />
            Rewards, made transparent
          </div>

          <h1 className="mt-6 text-balance text-[clamp(2.4rem,8vw,4.5rem)] font-black leading-[0.95] tracking-[-0.055em] text-ink-fg">
            Turn your time into <span className="text-gold">real rewards.</span>
          </h1>

          <p className="mt-6 max-w-lg text-pretty text-[15px] leading-7 text-ink-muted sm:text-lg sm:leading-8">
            Noble Gain is a simple rewards platform: pick an opportunity, complete it, and collect
            points you can redeem. Every value, status and payout stays visible.
          </p>

          <div className="mt-9 flex flex-col gap-3">
            <div className="flex gap-3 sm:hidden">
              <Link
                to="/auth"
                search={{ mode: "signup" }}
                className="group inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-xl bg-gold px-4 text-sm font-bold tracking-tight text-ink transition-transform duration-200 hover:-translate-y-0.5"
              >
                Get Started
                <ArrowRight className="size-4 transition-transform duration-200 group-hover:translate-x-0.5" />
              </Link>
              <Link
                to="/auth"
                search={{ mode: "login" }}
                className="inline-flex h-12 flex-1 items-center justify-center rounded-xl border border-hairline bg-ink-2/70 px-4 text-sm font-bold tracking-tight text-ink-fg transition-colors duration-200 hover:border-gold/30 hover:text-gold"
              >
                Sign in
              </Link>
            </div>

            <div className="hidden sm:flex sm:items-center sm:gap-3">
              <Link
                to="/auth"
                search={{ mode: "signup" }}
                className="group inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-xl bg-gold px-4 text-sm font-bold tracking-tight text-ink transition-transform duration-200 hover:-translate-y-0.5 sm:h-13 sm:flex-none"
              >
                Get Started
                <ArrowRight className="size-4 transition-transform duration-200 group-hover:translate-x-0.5" />
              </Link>
              <a
                href="#how-it-works"
                className="inline-flex h-12 flex-1 items-center justify-center rounded-xl border border-hairline px-6 text-sm font-bold tracking-tight text-ink-fg transition-colors duration-200 hover:border-gold/30 hover:text-gold sm:h-13 sm:flex-none"
              >
                See how it works
              </a>
            </div>

            <a
              href="#how-it-works"
              className="inline-flex h-12 items-center justify-center rounded-xl border border-hairline px-6 text-sm font-bold tracking-tight text-ink-fg transition-colors duration-200 hover:border-gold/30 hover:text-gold sm:hidden"
            >
              See how it works
            </a>
          </div>

          <div className="mt-9 flex flex-wrap items-center gap-x-6 gap-y-3 text-[13px] font-medium text-ink-muted">
            <span className="flex items-center gap-2">
              <CircleCheck className="size-4 text-gold" /> Free to join
            </span>
            <span className="flex items-center gap-2">
              <ShieldCheck className="size-4 text-gold" /> Secure, verified accounts
            </span>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, scale: 0.96, y: 18 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{
            duration: 0.75,
            delay: 0.12,
            ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number],
          }}
          className="relative w-full"
        >
          <div className="pointer-events-none absolute -inset-6 -z-10 rounded-[2.5rem] bg-gold/6 blur-2xl" />
          <DashboardMockup className="mock-float shadow-2xl shadow-foreground/10" />
        </motion.div>
      </div>
    </section>
  );
}

function ValuePropsBar() {
  return (
    <div className="border-y border-hairline bg-ink-2/40">
      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-y-6 px-4 py-8 sm:px-6 lg:grid-cols-4 lg:gap-6">
        {[
          { icon: Sparkles, label: "Simple earning experience" },
          { icon: ChartLine, label: "Transparent activity tracking" },
          { icon: ShieldCheck, label: "Secure account management" },
          { icon: CircleCheck, label: "Built for everyday users" },
        ].map((item) => (
          <div key={item.label} className="flex min-w-0 items-center gap-2.5">
            <item.icon className="size-4 shrink-0 text-gold" />
            <span className="text-xs font-semibold tracking-tight text-ink-muted sm:text-[13px]">
              {item.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function OpportunitiesSection() {
  return (
    <SectionWrapper id="opportunities">
      <FadeIn className="max-w-2xl">
        <SectionEyebrow>The platform</SectionEyebrow>
        <h2 className="mt-4 text-[clamp(1.9rem,5.4vw,3.25rem)] font-black leading-[1.02] tracking-[-0.045em] text-ink-fg">
          Everything you need to earn, in one place.
        </h2>
        <p className="mt-5 text-[15px] leading-7 text-ink-muted sm:text-base">
          Noble Gain brings opportunities, verification, progress and reward redemption into a
          single account. You always know what an activity is worth and where it stands.
        </p>
      </FadeIn>

      <div className="mt-10 grid gap-3 sm:mt-14 sm:grid-cols-2 lg:grid-cols-3">
        <FadeIn className="sm:col-span-2">
          <article className="group h-full rounded-2xl border border-hairline bg-ink-2/60 p-6 transition-all duration-300 hover:-translate-y-1 hover:border-gold/25 sm:p-8">
            <span className="grid size-10 place-items-center rounded-xl bg-gold/10 text-gold">
              <Compass className="size-5" />
            </span>
            <p className="mt-6 text-[11px] font-bold uppercase tracking-[0.18em] text-ink-muted">
              Discover
            </p>
            <h3 className="mt-2 text-xl font-black tracking-[-0.03em] text-ink-fg sm:text-2xl">
              Opportunities organised by category and reward
            </h3>
            <p className="mt-3 max-w-lg text-sm leading-6 text-ink-muted">
              Browse available activities with the point value shown upfront, including instant
              activities and ones that require a short review.
            </p>
          </article>
        </FadeIn>

        {[
          {
            icon: Wallet,
            label: "Balance",
            title: "Track your earnings",
            desc: "Every credit and redemption is recorded in your transaction history.",
          },
          {
            icon: CircleCheck,
            label: "Complete",
            title: "Submit activities",
            desc: "Finish an activity, submit it, and follow its status through to verification.",
          },
          {
            icon: ChartColumn,
            label: "Progress",
            title: "Monitor momentum",
            desc: "Daily activity, streaks and referral performance in one clear view.",
          },
          {
            icon: Gift,
            label: "Rewards",
            title: "Redeem your points",
            desc: "Exchange collected points for available rewards and track each request.",
          },
          {
            icon: Lock,
            label: "Security",
            title: "Protected account",
            desc: "Email verification, role-based access and per-account data rules.",
          },
        ].map((item, idx) => (
          <FadeIn key={item.title} delay={idx * 0.04}>
            <article className="group h-full rounded-2xl border border-hairline bg-ink-2/40 p-6 transition-all duration-300 hover:-translate-y-1 hover:border-gold/25">
              <span className="grid size-9 place-items-center rounded-lg bg-gold/10 text-gold">
                <item.icon className="size-4" />
              </span>
              <p className="mt-5 text-[11px] font-bold uppercase tracking-[0.18em] text-ink-muted">
                {item.label}
              </p>
              <h3 className="mt-1.5 text-lg font-black tracking-[-0.03em] text-ink-fg">
                {item.title}
              </h3>
              <p className="mt-2 text-sm leading-6 text-ink-muted">{item.desc}</p>
            </article>
          </FadeIn>
        ))}
      </div>
    </SectionWrapper>
  );
}

function InsideSection() {
  return (
    <SectionWrapper className="border-t border-hairline">
      <FadeIn className="max-w-xl">
        <SectionEyebrow>Inside Noble Gain</SectionEyebrow>
        <h2 className="mt-4 text-[clamp(1.75rem,4.8vw,2.75rem)] font-black leading-[1.05] tracking-[-0.045em] text-ink-fg">
          See exactly how it works before you join.
        </h2>
      </FadeIn>

      <div className="mt-12 space-y-14 sm:mt-16 sm:space-y-24">
        {[
          {
            eyebrow: "Discovery",
            title: "Find the next opportunity in seconds",
            desc: "Available activities are grouped by category with the reward value attached, so nothing is hidden behind a click.",
            mock: <OpportunitiesMockup />,
          },
          {
            eyebrow: "Earnings",
            title: "A dashboard that stays honest",
            desc: "Balance, daily progress and recent credits update as your activity is verified.",
            mock: <DashboardMockup />,
            flip: true,
          },
          {
            eyebrow: "History",
            title: "Every submission has a status",
            desc: "Pending, verified or needs revision — with the reason attached when something is returned.",
            mock: <ActivityMockup />,
          },
          {
            eyebrow: "Redemption",
            title: "Turn points into rewards",
            desc: "Redeem when you reach a reward's point cost and follow the request from submitted to fulfilled.",
            mock: <RewardsMockup />,
            flip: true,
          },
        ].map((item) => (
          <FadeIn key={item.title}>
            <div className="grid items-center gap-8 lg:grid-cols-2 lg:gap-16">
              <div className={item.flip ? "lg:order-2" : ""}>
                <SectionEyebrow>{item.eyebrow}</SectionEyebrow>
                <h3 className="mt-3 text-2xl font-black tracking-[-0.04em] text-ink-fg sm:text-3xl">
                  {item.title}
                </h3>
                <p className="mt-4 max-w-md text-sm leading-7 text-ink-muted sm:text-[15px]">
                  {item.desc}
                </p>
              </div>
              <div className={item.flip ? "lg:order-1" : ""}>{item.mock}</div>
            </div>
          </FadeIn>
        ))}
      </div>
    </SectionWrapper>
  );
}

function HowItWorksSection() {
  return (
    <SectionWrapper id="how-it-works" className="border-t border-hairline bg-ink-2/30">
      <FadeIn className="max-w-xl">
        <SectionEyebrow>How it works</SectionEyebrow>
        <h2 className="mt-4 text-[clamp(1.75rem,4.8vw,2.75rem)] font-black leading-[1.05] tracking-[-0.045em] text-ink-fg">
          Four steps from sign-up to reward.
        </h2>
      </FadeIn>

      <div className="mt-10 grid gap-px overflow-hidden rounded-2xl border border-hairline bg-[color:var(--hairline)] sm:mt-14 sm:grid-cols-2 lg:grid-cols-4">
        {[
          {
            n: "01",
            t: "Create your account",
            d: "Sign up with your email and verify it to activate your account.",
          },
          {
            n: "02",
            t: "Choose an opportunity",
            d: "Pick an available activity and see its reward before you start.",
          },
          {
            n: "03",
            t: "Complete the activity",
            d: "Submit your work; instant activities credit right away.",
          },
          {
            n: "04",
            t: "Receive and track your reward",
            d: "Points land in your balance and stay visible in your history.",
          },
        ].map((item, idx) => (
          <FadeIn key={item.n} delay={idx * 0.05}>
            <div className="h-full bg-ink px-6 py-8 transition-colors duration-300 hover:bg-ink-2/70">
              <p className="text-3xl font-black tracking-[-0.05em] text-gold/80 sm:text-4xl">
                {item.n}
              </p>
              <h3 className="mt-5 text-base font-black tracking-[-0.02em] text-ink-fg">{item.t}</h3>
              <p className="mt-2 text-sm leading-6 text-ink-muted">{item.d}</p>
            </div>
          </FadeIn>
        ))}
      </div>
    </SectionWrapper>
  );
}

function BenefitsSection() {
  return (
    <SectionWrapper id="benefits" className="border-t border-hairline">
      <div className="grid gap-10 lg:grid-cols-[0.95fr_1fr] lg:gap-16">
        <FadeIn>
          <SectionEyebrow>Why Noble Gain</SectionEyebrow>
          <h2 className="mt-4 text-[clamp(1.75rem,4.8vw,2.75rem)] font-black leading-[1.05] tracking-[-0.045em] text-ink-fg">
            Built to be understood, not guessed at.
          </h2>
          <p className="mt-5 text-sm leading-7 text-ink-muted sm:text-[15px]">
            Earning should be predictable. Noble Gain shows what each activity is worth, what state
            it is in, and what your points can be exchanged for — before you commit your time.
          </p>
          <div className="mt-8">
            <DashboardMockup className="mock-float" />
          </div>
        </FadeIn>

        <FadeIn delay={0.05}>
          <ul className="divide-y divide-[color:var(--hairline)] border-y border-hairline">
            {[
              {
                t: "Transparency",
                d: "Point values, statuses and reasons are always visible.",
              },
              {
                t: "Ease of use",
                d: "A focused interface with no unnecessary steps.",
              },
              {
                t: "Progress tracking",
                d: "Daily activity, streaks and referrals in one dashboard.",
              },
              {
                t: "Simple redemption",
                d: "Exchange points for rewards with a clear request trail.",
              },
              {
                t: "Secure by design",
                d: "Verified accounts and strict per-user data access.",
              },
            ].map((item) => (
              <li key={item.t} className="group flex gap-4 py-5">
                <span className="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-gold/10 text-gold transition-transform duration-300 group-hover:scale-105">
                  <CircleCheck className="size-4" />
                </span>
                <div className="min-w-0">
                  <h3 className="text-base font-black tracking-[-0.02em] text-ink-fg">{item.t}</h3>
                  <p className="mt-1 text-sm leading-6 text-ink-muted">{item.d}</p>
                </div>
              </li>
            ))}
          </ul>
        </FadeIn>
      </div>
    </SectionWrapper>
  );
}

function FaqSection() {
  return (
    <SectionWrapper id="faq" className="border-t border-hairline bg-ink-2/30">
      <div className="grid gap-10 lg:grid-cols-[0.7fr_1fr] lg:gap-16">
        <FadeIn>
          <SectionEyebrow>FAQ</SectionEyebrow>
          <h2 className="mt-4 text-[clamp(1.75rem,4.8vw,2.5rem)] font-black leading-[1.06] tracking-[-0.045em] text-ink-fg">
            Answers before you sign up.
          </h2>
        </FadeIn>

        <FadeIn delay={0.05}>
          <Accordion type="single" collapsible className="w-full">
            {[
              {
                q: "How does Noble Gain work?",
                a: "You create an account, choose from the available activities, complete them, and receive points. Points are recorded in your balance and can be redeemed for available rewards.",
              },
              {
                q: "Is it free to join?",
                a: "Yes. Creating a Noble Gain account is free and there is no subscription.",
              },
              {
                q: "How do I earn?",
                a: "By completing available activities, keeping a daily streak, and referring people who complete their first activity. Each activity shows its point value before you start.",
              },
              {
                q: "How are rewards tracked?",
                a: "Every credit and redemption appears in your transaction history, and each submission carries a status: pending, verified or returned with a reason.",
              },
              {
                q: "How do withdrawals work?",
                a: "Points are exchanged for rewards from the rewards catalogue. Once you meet a reward's point cost you submit a redemption request and follow its status until it is fulfilled.",
              },
              {
                q: "Can I use Noble Gain on mobile?",
                a: "Yes. The platform is fully responsive, with a dedicated mobile navigation for the dashboard, activities and rewards.",
              },
              {
                q: "How is my account protected?",
                a: "Accounts are verified by email, access is role-based, and account data is restricted per user at the database level.",
              },
            ].map((item) => (
              <AccordionItem
                key={item.q}
                value={item.q}
                className="border-b border-[color:var(--hairline)]"
              >
                <AccordionTrigger className="py-5 text-left text-[15px] font-bold tracking-tight text-ink-fg hover:no-underline cursor-pointer">
                  {item.q}
                </AccordionTrigger>
                <AccordionContent className="pb-5 text-sm leading-7 text-ink-muted">
                  {item.a}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </FadeIn>
      </div>
    </SectionWrapper>
  );
}

function CtaSection() {
  return (
    <SectionWrapper className="border-t border-hairline">
      <FadeIn>
        <div className="relative overflow-hidden rounded-3xl border border-hairline bg-ink-2/60 px-6 py-14 text-center sm:px-12 sm:py-20">
          <div className="pointer-events-none absolute -top-24 left-1/2 size-72 -translate-x-1/2 rounded-full bg-gold/12 blur-3xl ink-breathe" />
          <div className="relative">
            <h2 className="text-[clamp(1.85rem,5.2vw,3rem)] font-black leading-[1.03] tracking-[-0.045em] text-ink-fg">
              Ready to start earning?
            </h2>
            <p className="mx-auto mt-4 max-w-md text-sm leading-7 text-ink-muted sm:text-base">
              Join Noble Gain and turn your available time into meaningful progress.
            </p>
            <Link
              to="/auth"
              search={{ mode: "signup" }}
              className="group mt-8 inline-flex h-12 items-center gap-2 rounded-xl bg-gold px-6 text-sm font-bold tracking-tight text-ink transition-transform duration-200 hover:-translate-y-0.5 sm:h-13"
            >
              Get Started
              <ArrowRight className="size-4 transition-transform duration-200 group-hover:translate-x-0.5" />
            </Link>
          </div>
        </div>
      </FadeIn>
    </SectionWrapper>
  );
}

import { PublicFooter } from "@/components/PublicFooter";

function LandingPage() {
  return (
    <div className="min-h-screen bg-ink text-ink-fg">
      <LandingNav />
      <main>
        <HeroSection />
        <ValuePropsBar />
        <OpportunitiesSection />
        <InsideSection />
        <HowItWorksSection />
        <BenefitsSection />
        <FaqSection />
        <CtaSection />
      </main>
      <PublicFooter />
    </div>
  );
}

export default LandingPage;
