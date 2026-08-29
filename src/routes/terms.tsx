import { createFileRoute, Link } from "@tanstack/react-router";
import { LandingNav } from "@/components/LandingNav";
import { PublicFooter } from "@/components/PublicFooter";
import { Lock, ArrowRight } from "lucide-react";

export const Route = createFileRoute("/terms")({
  head: () => {
    const url =
      typeof window !== "undefined" ? window.location.origin : "";
    const canonicalUrl = `${url}/terms`;

    return {
      title: "Terms of Service | Noble Gain",
      meta: [
        {
          name: "description",
          content:
            "Read the Noble Gain terms of service. Understand our rules, user obligations, and platform policies before you start earning.",
        },
        { property: "og:title", content: "Terms of Service | Noble Gain" },
        {
          property: "og:description",
          content: "The rules of the road for Noble Gain. Read our terms of service.",
        },
        { property: "og:url", content: canonicalUrl },
        { property: "og:type", content: "website" },
        { property: "og:image", content: `${url}/logo.png` },
        { name: "twitter:card", content: "summary_large_image" },
      ],
      links: [{ rel: "canonical", href: canonicalUrl }],
    };
  },
  component: TermsPage,
});

function TermsPage() {
  return (
    <div className="min-h-screen bg-ink text-ink-fg flex flex-col">
      <LandingNav />

      <main className="flex-1">
        <section className="relative isolate overflow-hidden px-4 pb-12 pt-32 sm:px-6 md:pb-16 md:pt-40">
          <div className="pointer-events-none absolute inset-0 -z-10 ink-dots opacity-40 [mask-image:linear-gradient(to_bottom,black,transparent_75%)]" />
          <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 size-[34rem] -translate-x-1/2 rounded-full bg-gold/10 blur-[120px] ink-breathe" />

          <div className="mx-auto max-w-4xl">
            <div className="inline-flex items-center gap-2 rounded-full border border-hairline bg-ink-2/70 px-3.5 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-gold mb-6">
              <Lock className="size-3.5" /> Platform Rules & Terms
            </div>
            <h1 className="text-balance text-4xl sm:text-5xl font-black tracking-[-0.04em] text-ink-fg">
              Terms of Service
            </h1>
            <p className="mt-3 text-sm text-ink-muted">Last updated: August 2026</p>
          </div>
        </section>

        <section className="border-t border-hairline px-4 py-12 sm:px-6 md:py-16">
          <div className="mx-auto max-w-4xl">
            <div className="rounded-3xl border border-hairline bg-ink-2/50 p-6 sm:p-10 md:p-12 space-y-10 text-sm sm:text-[15px] leading-7 text-ink-fg/85">
              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  1. Agreement to Terms
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  By accessing or registering an account on Noble Gain ("the Platform"), you agree
                  to abide by these Terms of Service. If you do not agree with any part of these
                  terms, you must discontinue use of the platform immediately.
                </p>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  2. User Eligibility & Account Security
                </h2>
                <ul className="list-disc pl-6 space-y-2 text-ink-muted">
                  <li>
                    You must provide accurate and verifiable email information upon registration.
                  </li>
                  <li>
                    Each individual user is permitted to maintain only{" "}
                    <strong className="text-ink-fg">one (1) account</strong>. Creating multiple
                    accounts or using VPN/proxy circumvention to farm rewards is strictly
                    prohibited.
                  </li>
                  <li>
                    You are solely responsible for maintaining the confidentiality of your
                    credentials and all activity conducted through your account.
                  </li>
                </ul>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  3. Task Submissions & Verification
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  Tasks submitted for point credits must comply with the stated instructions for
                  each opportunity. The platform reserves the right to review, approve, reject, or
                  request revisions for submissions that do not meet verification criteria.
                  Submitting fake, altered, or duplicate proof will result in forfeiture of points
                  and possible account termination.
                </p>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  4. Points, Rewards & Redemptions
                </h2>
                <ul className="list-disc pl-6 space-y-2 text-ink-muted">
                  <li>
                    Points accrued within Noble Gain have no direct cash value outside the platform
                    until successfully redeemed through available catalog rewards.
                  </li>
                  <li>
                    Redemption requests undergo a security review before fulfillment to verify
                    compliance with platform guidelines.
                  </li>
                  <li>
                    Available rewards, redemption thresholds, and point exchange rates are subject
                    to availability and updates by the platform administration.
                  </li>
                </ul>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  5. Termination & Policy Violations
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  Noble Gain reserves the right to suspend or permanently ban accounts found
                  engaging in automated botting, fraudulent task submissions, referral abuse, or
                  harassment within the community.
                </p>
              </section>

              <div className="pt-8 border-t border-hairline flex flex-col sm:flex-row gap-4 justify-between items-center">
                <Link
                  to="/"
                  className="group inline-flex items-center gap-2 text-sm font-bold text-gold hover:underline"
                >
                  ← Return to Home
                </Link>
                <Link
                  to="/auth"
                  search={{ mode: "signup" }}
                  className="group inline-flex h-11 items-center gap-2 rounded-xl bg-gold px-5 text-xs font-bold uppercase tracking-wider text-ink transition-transform hover:-translate-y-0.5"
                >
                  Get Started
                  <ArrowRight className="size-3.5" />
                </Link>

              </div>
            </div>
          </div>
        </section>
      </main>

      <PublicFooter />
    </div>
  );
}

export default TermsPage;
