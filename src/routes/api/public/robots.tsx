import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/api/public/robots")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const url = new URL(request.url);
        const baseUrl = `${url.protocol}//${url.host}`;

        const robots = `User-agent: *
Allow: /
Allow: /about
Allow: /earn
Allow: /redeem
Allow: /refer
Allow: /privacy
Allow: /terms
Disallow: /admin
Disallow: /settings
Disallow: /api/

Sitemap: ${baseUrl}/api/public/sitemap`;

        return new Response(robots, {
          headers: {
            "Content-Type": "text/plain",
          },
        });
      },
    },
  },
});
