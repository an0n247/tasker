import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/api/public/og")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const { searchParams } = new URL(request.url);
        const escapeXml = (value: string, maxLength: number) =>
          value
            .slice(0, maxLength)
            .replace(/[<>&"']/g, (c) =>
              c === "<"
                ? "&lt;"
                : c === ">"
                  ? "&gt;"
                  : c === "&"
                    ? "&amp;"
                    : c === '"'
                      ? "&quot;"
                      : "&apos;",
            );
        const title = escapeXml(searchParams.get("title") || "Noble Gain", 60);
        const description = escapeXml(searchParams.get("description") || "Reward Your Time", 120);

        // We'll generate a high-quality SVG that serves as a dynamic OpenGraph image.
        // This is safe for Workers as it doesn't use native binaries.
        const svg = `
          <svg width="1200" height="630" viewBox="0 0 1200 630" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#002d26;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#001a16;stop-opacity:1" />
              </linearGradient>
              <filter id="shadow" x="0" y="0" width="200%" height="200%">
                <feOffset result="offOut" in="SourceAlpha" dx="0" dy="4" />
                <feGaussianBlur result="blurOut" in="offOut" stdDeviation="10" />
                <feBlend in="SourceGraphic" in2="blurOut" mode="normal" />
              </filter>
            </defs>
            
            <rect width="1200" height="630" fill="#F8F9FB" />
            <rect width="1160" height="590" x="20" y="20" rx="40" fill="url(#grad1)" />
            
            <g transform="translate(100, 200)">
              <text font-family="Urbanist, sans-serif" font-weight="900" font-size="80" fill="#FFFFFF" letter-spacing="-0.04em">
                ${title.toUpperCase()}
              </text>
              <text font-family="Urbanist, sans-serif" font-weight="500" font-size="32" fill="#FFFFFF" opacity="0.8" y="80">
                ${description}
              </text>
            </g>

            <g transform="translate(100, 500)">
              <circle cx="25" cy="25" r="25" fill="#FFFFFF" opacity="0.2" />
              <path d="M25 15C19.48 15 15 19.48 15 25C15 30.52 19.48 35 25 35C30.52 35 35 30.52 35 25C35 19.48 30.52 15 25 15ZM26 30H24V24H20V22H26V30Z" fill="#FFFFFF" />
              <text x="65" y="32" font-family="Urbanist, sans-serif" font-weight="900" font-size="24" fill="#FFFFFF" letter-spacing="0.1em">
                NOBLE GAIN
              </text>
            </g>

            <circle cx="1050" cy="150" r="100" fill="#FFFFFF" opacity="0.1" />
            <circle cx="1100" cy="500" r="150" fill="#FFFFFF" opacity="0.05" />
          </svg>
        `.trim();

        return new Response(svg, {
          headers: {
            "Content-Type": "image/svg+xml",
            "Cache-Control": "public, max-age=31536000, immutable",
          },
        });
      },
    },
  },
});
