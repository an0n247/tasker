import { getRequest } from "@tanstack/react-start/server";

const IPV4 = /^(\d{1,3}\.){3}\d{1,3}$/;

function isValidIp(value: string): boolean {
  if (IPV4.test(value)) {
    return value.split(".").every((part) => Number(part) <= 255);
  }
  // Loose IPv6 check: hex groups separated by colons.
  return value.includes(":") && /^[0-9a-fA-F:.]+$/.test(value);
}

/**
 * Resolves the real client IP from the incoming request headers.
 * Returns null when no trustworthy value is available — never a placeholder.
 */
export function getClientIpFromRequest(): string | null {
  const request = getRequest();
  const headers = request?.headers;
  if (!headers) return null;

  // Cloudflare / common proxy headers, most specific first.
  const candidates: string[] = [];

  const single = ["cf-connecting-ip", "true-client-ip", "x-real-ip"];
  for (const name of single) {
    const value = headers.get(name);
    if (value) candidates.push(value.trim());
  }

  const forwarded = headers.get("x-forwarded-for");
  if (forwarded) {
    // Left-most entry is the original client.
    for (const part of forwarded.split(",")) candidates.push(part.trim());
  }

  for (const candidate of candidates) {
    const cleaned = candidate.replace(/^\[|\]$/g, "");
    if (cleaned && isValidIp(cleaned)) return cleaned;
  }

  return null;
}
