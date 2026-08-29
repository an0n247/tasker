import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { getClientIpFromRequest } from "./client-ip.server";

/**
 * Returns the caller's own public IP as seen by the server.
 * Public on purpose: it only ever discloses the requester's own address.
 */
export const getClientIp = createServerFn({ method: "GET" }).handler(async () => {
  return { ip: getClientIpFromRequest() };
});

/**
 * Records the signed-in user's real client IP (derived server-side from the
 * request, never supplied by the browser) plus their device fingerprint.
 */
export const recordClientSession = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .validator((data) =>
    z.object({ fingerprint: z.string().min(1).max(128).nullish() }).parse(data ?? {}),
  )
  .handler(async ({ data, context }) => {
    const ip = getClientIpFromRequest();

    const update: Record<string, string> = {};
    if (ip) update["last_ip"] = ip;
    if (data.fingerprint) update["fingerprint"] = data.fingerprint;

    if (Object.keys(update).length === 0) return { recorded: false, ip: null };

    const { error } = await context.supabase
      .from("profiles")
      .update(update as never)
      .eq("id", context.userId);

    if (error) {
      console.error("Failed to record client session:", error);
      throw new Error(error.message);
    }

    return { recorded: true, ip };
  });
