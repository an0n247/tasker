import { createFileRoute, Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import {
  ShieldCheck,
  Target,
  Users,
  Sparkles,
  ArrowRight,
  Globe,
  Zap,
  TrendingUp,
  CircleCheck,
} from "lucide-react";
import { LandingNav } from "@/components/LandingNav";
import { PublicFooter } from "@/components/PublicFooter";

export const Route = createFileRoute("/about")({
  head: () => ({
    title: "About Noble Gain | Our Mission & Brand Story",
    meta: [
      {
        name: "description",
        content:
          "Learn about Noble Gain's mission to empower digital users through a transparent, secure, and rewarding platform. Discover our story and key features.",
      },
      { property: "og:title", content: "About Noble Gain | Empowering Your Digital Time" },
      {
        property: "og:description",
        content:
          "Discover how Noble Gain is redefining the rewards economy with transparency, security, and global reach.",
      },
      { property: "og:image", content: "/logo.png" },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: AboutPage,
});

const reveal = {
  hidden: { opacity: 0, y: 22 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.22, 0.8, 0.2, 1] as [number, number, number, number] },
  },
};

const storyTimeline = [
  {
    year: "Phase 1",
    title: "A Simple Vision",
    description:
      "Noble Gain started with a single purpose: to prove that digital activity should have tangible, predictable value for everyday users, not just large networks.",
  },
  {
    year: "Phase 2",
    title: "Transparent Rewards",
    description:
      "We built an upfront rewards architecture where point values, verification statuses, and payout criteria remain 100% visible before users spend their time.",
  },
  {
    year: "Phase 3",
    title: "Global Platform",
    description:
      "Today, Noble Gain empowers users worldwide with streamlined task submissions, verified referrals, instant redemptions, and enterprise security.",
  },
];

const pillars = [
  {
    title: "Transparency First",
    icon: Globe,
    desc: "Every point earned and every referral credited is recorded in real-time. No hidden deductions, no surprise fees, and no opaque status updates.",
  },
  {
    title: "Protected Security",
    icon: ShieldCheck,
    desc: "We enforce role-based access, strict per-account database isolation, and encrypted transaction trails to ensure your balance is safe.",
  },
  {
    title: "Empowered Community",
    icon: Users,
    desc: "Our ecosystem thrives on genuine participation. Our referral network gives back high-tier bonuses when your friends complete their first tasks.",
  },
];

function AboutPage() {
  return (
    <div className="min-h-screen bg-ink text-ink-fg flex flex-col">
      <LandingNav />

      <main className="flex-1">
        {/* Hero Section */}
        <section className="relative isolate overflow-hidden px-4 pb-20 pt-32 sm:px-6 md:pb-28 md:pt-40">
          <div className="pointer-events-none absolute inset-0 -z-10 ink-dots opacity-40 [mask-image:linear-gradient(to_bottom,black,transparent_75%)]" />
          <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 size-[34rem] -translate-x-1/2 rounded-full bg-gold/10 blur-[120px] ink-breathe" />

          <div className="mx-auto max-w-4xl text-center">
            <motion.div initial="hidden" animate="visible" variants={reveal}>
              <div className="inline-flex items-center gap-2 rounded-full border border-hairline bg-ink-2/70 px-3.5 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-gold mb-6">
                <Sparkles className="size-3.5" /> Our Mission & Vision
              </div>
              <h1 className="text-balance text-[clamp(2.4rem,7vw,4.2rem)] font-black leading-[0.96] tracking-[-0.055em] text-ink-fg">
                Empowering your <span className="text-gold">digital time.</span>
              </h1>
              <p className="mt-6 mx-auto max-w-2xl text-pretty text-[15px] leading-7 text-ink-muted sm:text-lg sm:leading-8">
                Noble Gain is built on a clear principle: everyday digital interactions have real
                value. We give you transparent tools to collect rewards, track your progress, and
                redeem with confidence.
              </p>
            </motion.div>
          </div>
        </section>

        {/* Mission Section */}
        <section className="border-t border-hairline px-4 py-20 sm:px-6 md:py-28 bg-ink-2/30">
          <div className="mx-auto max-w-6xl">
            <div className="grid md:grid-cols-2 gap-12 lg:gap-16 items-center">
              <motion.div
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true }}
                variants={reveal}
              >
                <div className="flex size-12 items-center justify-center rounded-xl bg-gold/10 text-gold mb-6">
                  <Target className="size-6" />
                </div>
                <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-gold">
                  The Goal
                </p>
                <h2 className="mt-2 text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
                  Democratizing the digital rewards economy.
                </h2>
                <p className="mt-5 text-sm leading-7 text-ink-muted sm:text-[15px]">
                  Too often, internet users provide valuable engagement without receiving anything
                  tangible in return. Noble Gain connects users directly with verified
                  opportunities, displaying the point value upfront before you commit your time.
                </p>
                <p className="mt-4 text-sm leading-7 text-ink-muted sm:text-[15px]">
                  Whether you are checking in daily, exploring partner tasks, or referring
                  colleagues, our system tracks every step until fulfillment.
                </p>
                <div className="mt-6 flex flex-wrap gap-4 text-xs font-semibold text-ink-fg/90">
                  <span className="flex items-center gap-1.5">
                    <CircleCheck className="size-4 text-gold" /> Zero hidden fees
                  </span>
                  <span className="flex items-center gap-1.5">
                    <CircleCheck className="size-4 text-gold" /> Clear point calculations
                  </span>
                  <span className="flex items-center gap-1.5">
                    <CircleCheck className="size-4 text-gold" /> Fast reward payouts
                  </span>
                </div>
              </motion.div>

              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.6 }}
                className="relative overflow-hidden rounded-3xl border border-hairline bg-ink-2/80 p-8 sm:p-12 shadow-2xl flex flex-col items-center justify-center text-center mock-sheen"
              >
                <div className="pointer-events-none absolute -inset-6 -z-10 rounded-[2.5rem] bg-gold/5 blur-2xl" />
                <img
                  src="/logo.png"
                  alt="Noble Gain"
                  className="size-28 sm:size-36 object-contain mb-6 mock-float"
                />
                <h3 className="text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  Noble<span className="text-gold">Gain</span>
                </h3>
                <p className="mt-2 text-xs font-medium text-ink-muted max-w-xs">
                  Transparent rewards community built for everyday users worldwide.
                </p>
              </motion.div>
            </div>
          </div>
        </section>

        {/* Pillars Section */}
        <section className="border-t border-hairline px-4 py-20 sm:px-6 md:py-28">
          <div className="mx-auto max-w-6xl">
            <div className="text-center max-w-2xl mx-auto mb-16">
              <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-gold">
                Our Foundation
              </p>
              <h2 className="mt-2 text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
                The Noble Principles
              </h2>
              <p className="mt-4 text-sm leading-7 text-ink-muted sm:text-[15px]">
                Built on honesty, robust engineering, and a focus on straightforward member
                experiences.
              </p>
            </div>

            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {pillars.map((pillar, i) => (
                <motion.article
                  key={pillar.title}
                  initial="hidden"
                  whileInView="visible"
                  viewport={{ once: true }}
                  variants={{
                    hidden: { opacity: 0, y: 18 },
                    visible: { opacity: 1, y: 0, transition: { delay: i * 0.08, duration: 0.5 } },
                  }}
                  className="group rounded-2xl border border-hairline bg-ink-2/50 p-6 sm:p-8 transition-all duration-300 hover:-translate-y-1 hover:border-gold/25"
                >
                  <div className="flex size-10 items-center justify-center rounded-xl bg-gold/10 text-gold mb-6 group-hover:scale-105 transition-transform">
                    <pillar.icon className="size-5" />
                  </div>
                  <h3 className="text-lg font-black tracking-[-0.03em] text-ink-fg mb-2">
                    {pillar.title}
                  </h3>
                  <p className="text-sm leading-6 text-ink-muted">{pillar.desc}</p>
                </motion.article>
              ))}
            </div>
          </div>
        </section>

        {/* Story Timeline */}
        <section className="border-t border-hairline px-4 py-20 sm:px-6 md:py-28 bg-ink-2/30">
          <div className="mx-auto max-w-4xl">
            <div className="text-center max-w-xl mx-auto mb-16">
              <p className="text-[11px] font-bold uppercase tracking-[0.2em] text-gold">Roadmap</p>
              <h2 className="mt-2 text-3xl sm:text-4xl font-black tracking-[-0.04em] text-ink-fg">
                The Journey
              </h2>
            </div>

            <div className="space-y-6">
              {storyTimeline.map((item, idx) => (
                <motion.div
                  key={item.year}
                  initial="hidden"
                  whileInView="visible"
                  viewport={{ once: true }}
                  variants={reveal}
                  className="flex flex-col sm:flex-row gap-4 sm:gap-8 items-start rounded-2xl border border-hairline bg-ink p-6 sm:p-8 transition-colors hover:bg-ink-2/60"
                >
                  <div className="sm:w-28 shrink-0">
                    <span className="text-2xl font-black tracking-[-0.04em] text-gold">
                      {item.year}
                    </span>
                  </div>
                  <div className="flex-1">
                    <h3 className="text-lg font-black tracking-[-0.02em] text-ink-fg mb-2">
                      {item.title}
                    </h3>
                    <p className="text-sm leading-6 text-ink-muted">{item.description}</p>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        {/* CTA Section */}
        <section className="border-t border-hairline px-4 py-16 sm:px-6 md:py-24">
          <div className="mx-auto max-w-6xl">
            <div className="relative overflow-hidden rounded-3xl border border-hairline bg-ink-2/60 px-6 py-14 text-center sm:px-12 sm:py-20">
              <div className="pointer-events-none absolute -top-24 left-1/2 size-72 -translate-x-1/2 rounded-full bg-gold/12 blur-3xl ink-breathe" />
              <div className="relative">
                <h2 className="text-[clamp(1.85rem,5.2vw,3rem)] font-black leading-[1.03] tracking-[-0.045em] text-ink-fg">
                  Ready to experience Noble Gain?
                </h2>
                <p className="mx-auto mt-4 max-w-md text-sm leading-7 text-ink-muted sm:text-base">
                  Start your earning journey today with zero upfront cost.
                </p>
                <div className="mt-8 flex flex-col sm:flex-row justify-center gap-3">
                  <Link
                    to="/auth"
                    search={{ mode: "signup" }}
                    className="group inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-gold px-6 text-sm font-bold tracking-tight text-ink transition-transform duration-200 hover:-translate-y-0.5 sm:h-13"
                  >
                    Create Free Account
                    <ArrowRight className="size-4 transition-transform duration-200 group-hover:translate-x-0.5" />
                  </Link>
                  <Link
                    to="/auth"
                    className="inline-flex h-12 items-center justify-center rounded-xl border border-hairline px-6 text-sm font-bold tracking-tight text-ink-fg transition-colors duration-200 hover:border-gold/30 hover:text-gold sm:h-13"
                  >
                    Sign In
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      <PublicFooter />
    </div>
  );
}

export default AboutPage;
