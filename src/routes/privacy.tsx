import { createFileRoute, Link } from "@tanstack/react-router";
import { LandingNav } from "@/components/LandingNav";
import { PublicFooter } from "@/components/PublicFooter";
import { ShieldCheck, ArrowRight } from "lucide-react";

export const Route = createFileRoute("/privacy")({
  head: () => {
    const url =
      typeof window !== "undefined" ? window.location.origin : "";
    const canonicalUrl = `${url}/privacy`;

    return {
      title: "Privacy Policy | Noble Gain",
      meta: [
        {
          name: "description",
          content:
            "Learn how Noble Gain collects, uses, and protects your personal data. Our privacy policy outlines our commitment to your security.",
        },
        { property: "og:title", content: "Privacy Policy | Noble Gain" },
        {
          property: "og:description",
          content: "Your privacy is our priority. Read the Noble Gain privacy policy.",
        },
        { property: "og:url", content: canonicalUrl },
        { property: "og:type", content: "website" },
        { property: "og:image", content: `${url}/logo.png` },
        { name: "twitter:card", content: "summary_large_image" },
      ],
      links: [{ rel: "canonical", href: canonicalUrl }],
    };
  },
  component: PrivacyPage,
});

function PrivacyPage() {
  return (
    <div className="min-h-screen bg-ink text-ink-fg flex flex-col">
      <LandingNav />

      <main className="flex-1">
        <section className="relative isolate overflow-hidden px-4 pb-12 pt-32 sm:px-6 md:pb-16 md:pt-40">
          <div className="pointer-events-none absolute inset-0 -z-10 ink-dots opacity-40 [mask-image:linear-gradient(to_bottom,black,transparent_75%)]" />
          <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 size-[34rem] -translate-x-1/2 rounded-full bg-gold/10 blur-[120px] ink-breathe" />

          <div className="mx-auto max-w-4xl">
            <div className="inline-flex items-center gap-2 rounded-full border border-hairline bg-ink-2/70 px-3.5 py-1.5 text-[11px] font-bold uppercase tracking-[0.18em] text-gold mb-6">
              <ShieldCheck className="size-3.5" /> Legal & Security
            </div>
            <h1 className="text-balance text-4xl sm:text-5xl font-black tracking-[-0.04em] text-ink-fg">
              Privacy Policy
            </h1>
            <p className="mt-3 text-sm text-ink-muted">Last updated: August 2026</p>
          </div>
        </section>

        <section className="border-t border-hairline px-4 py-12 sm:px-6 md:py-16">
          <div className="mx-auto max-w-4xl">
            <div className="rounded-3xl border border-hairline bg-ink-2/50 p-6 sm:p-10 md:p-12 space-y-10 text-sm sm:text-[15px] leading-7 text-ink-fg/85">
              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  1. Overview & Commitment
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  Welcome to Noble Gain. We respect your privacy and are committed to safeguarding
                  your personal information. This Privacy Policy details how we collect, store,
                  utilize, and protect your data when you access our web application, participate in
                  reward opportunities, and manage your account balance.
                </p>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  2. Information We Collect
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  To provide seamless reward tracking, anti-abuse security, and payout fulfillment,
                  we may collect the following categories of data:
                </p>
                <ul className="list-disc pl-6 space-y-2 text-ink-muted">
                  <li>
                    <strong className="text-ink-fg">Account Identification:</strong> Email address,
                    user identifier, and public profile handle.
                  </li>
                  <li>
                    <strong className="text-ink-fg">Activity & Task Data:</strong> Task submission
                    proofs, screenshots, referral clicks, daily login streaks, and point logs.
                  </li>
                  <li>
                    <strong className="text-ink-fg">Technical & Device Metadata:</strong> IP
                    address, browser type, device resolution, and approximate timezone used solely
                    for anti-fraud detection and duplicate account prevention.
                  </li>
                  <li>
                    <strong className="text-ink-fg">Redemption Details:</strong> Payout destination
                    addresses (e.g. gift card delivery email or payment identifier).
                  </li>
                </ul>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  3. How Your Information Is Used
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  We use the information we collect strictly to:
                </p>
                <ul className="list-disc pl-6 space-y-2 text-ink-muted">
                  <li>Authenticate and maintain your personal account.</li>
                  <li>Verify completion of reward tasks and calculate accurate point balances.</li>
                  <li>Process, review, and fulfill reward redemption requests.</li>
                  <li>
                    Protect our community and partners against botting, duplicate accounts, and
                    fraudulent activity.
                  </li>
                  <li>Provide critical service updates and support assistance.</li>
                </ul>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  4. Data Protection & Security
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  We implement database-level row access policies (RLS), end-to-end encryption in
                  transit (HTTPS/TLS), and restricted access protocols. Your account credentials and
                  tokens are encrypted, and passwords are never stored in plaintext.
                </p>
              </section>

              <section className="space-y-3">
                <h2 className="text-xl sm:text-2xl font-black tracking-[-0.03em] text-ink-fg">
                  5. Your Data Rights
                </h2>
                <p className="text-ink-muted leading-relaxed">
                  You have the right to request a copy of your activity data, update your account
                  settings, or request account closure and deletion of associated personal data at
                  any time through your Profile settings or by contacting our support team.
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
                  Create Free Account
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

export default PrivacyPage;
