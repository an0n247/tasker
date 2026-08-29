import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

/**
 * Server-side image optimization function.
 * Accepts a base64 image or a URL (if public) and returns a sharp-optimized Buffer or Blob.
 *
 * NOTE: Since this is a Cloudflare Worker environment, we use standard Web APIs
 * and specific worker-compatible patterns. We don't have 'sharp' available here.
 * We can use the 'transform' options if calling Supabase Storage or just rely
 * on client-side pre-processing (which we already have via ImageCropper).
 *
 * However, the user specifically asked for SERVER-SIDE resizing.
 * In TanStack Start (Cloudflare Workers), we can't use 'sharp'.
 * We will implement a server function that provides the transformation URL parameters
 * for Supabase's built-in image transformation service.
 */

export const getOptimizedImageUrl = createServerFn({ method: "GET" })
  .validator((data) =>
    z
      .object({
        path: z.string(),
        bucket: z.enum(["avatars", "rewards"]),
        width: z.number().optional().default(400),
        height: z.number().optional().default(400),
        quality: z.number().optional().default(80),
        format: z.enum(["webp", "origin"]).optional().default("webp"),
      })
      .parse(data),
  )
  .handler(async ({ data }) => {
    // Supabase Storage supports image transformation via parameters if enabled.
    // URL format: https://[project-ref].supabase.co/storage/v1/render/image/public/[bucket]/[path]?width=[w]&height=[h]&resize=cover

    const SUPABASE_URL = process.env["VITE_SUPABASE_URL"];

    if (!SUPABASE_URL) {
      throw new Error("Supabase URL not configured");
    }

    const { bucket, path, width, height, quality, format } = data;

    // Construct the transformation URL
    // We use 'render/image/public' for public bucket access with transformations
    const url = new URL(`${SUPABASE_URL}/storage/v1/render/image/public/${bucket}/${path}`);
    url.searchParams.set("width", width.toString());
    url.searchParams.set("height", height.toString());
    url.searchParams.set("quality", quality.toString());
    url.searchParams.set("resize", "cover");
    if (format !== "origin") {
      url.searchParams.set("format", format);
    }

    return { url: url.toString() };
  });
