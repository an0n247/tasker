import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/api/public/dns-check")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const url = new URL(request.url);
        const domain = url.searchParams.get("domain") || "noblegain.bytsphere.buzz";

        try {
          // In a real Worker environment, we might use a DoH API or similar
          // For this check, we'll use Google's DNS-over-HTTPS API
          const response = await fetch(`https://dns.google/resolve?name=${domain}&type=CNAME`);
          const data = await response.json();

          const isDetected = data.Answer?.some(
            (a: any) =>
              a.data.includes("bytsphere.buzz") ||
              a.data.includes("lovable.app") ||
              a.data.includes("qd.je"),
          );

          return new Response(
            JSON.stringify({
              domain,
              status: isDetected ? "propagated" : "pending",
              records: data.Answer || [],
              timestamp: new Date().toISOString(),
            }),
            {
              headers: { "Content-Type": "application/json" },
            },
          );
        } catch (error) {
          return new Response(JSON.stringify({ error: "Failed to check DNS" }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
          });
        }
      },
    },
  },
});
