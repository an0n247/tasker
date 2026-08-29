import { supabase } from "@/integrations/supabase/client";

export function shouldWarnForBucketError(
  error: { message?: string | undefined; status?: number | undefined } | null,
  bucket: string,
  hasData: boolean,
): boolean {
  if (!error) return false;
  if (hasData) return false;

  const status = error.status ?? 0;
  const message = error.message?.toLowerCase() ?? "";

  const suppressedMessages = [
    "jwt expired",
    "unauthorized",
    "forbidden",
    "permission",
    "not allowed",
    "bad request",
    "missing required",
    "invalid token",
  ];

  const shouldSuppress =
    status === 401 ||
    status === 403 ||
    suppressedMessages.some((token) => message.includes(token));

  if (shouldSuppress) {
    return false;
  }

  if (status === 404 || message.includes("not found") || message.includes("bucket")) {
    return true;
  }

  return true;
}

export async function ensureBucketsExist() {
  const buckets = ["avatars", "rewards"];

  for (const bucket of buckets) {
    try {
      const { data, error } = await supabase.storage.getBucket(bucket);
      if (error && shouldWarnForBucketError(error, bucket, !!data)) {
        console.warn(`Bucket ${bucket} is missing or inaccessible:`, error.message);
      }
    } catch {
      // Ignore startup initialization noise when the app is already fully configured.
    }
  }
}
