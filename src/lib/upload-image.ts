import { supabase } from "@/integrations/supabase/client";

/**
 * Compresses an image File or Blob to a compact base64 data URL
 */
export async function blobToCompressedDataUrl(
  blobOrFile: Blob | File,
  maxWidth = 400,
  maxHeight = 400,
  quality = 0.85,
): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        const canvas = document.createElement("canvas");
        let width = img.width;
        let height = img.height;

        if (width > height) {
          if (width > maxWidth) {
            height = Math.round((height * maxWidth) / width);
            width = maxWidth;
          }
        } else {
          if (height > maxHeight) {
            width = Math.round((width * maxHeight) / height);
            height = maxHeight;
          }
        }

        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext("2d");
        if (!ctx) {
          resolve(e.target?.result as string);
          return;
        }

        ctx.drawImage(img, 0, 0, width, height);
        const dataUrl = canvas.toDataURL("image/jpeg", quality);
        resolve(dataUrl);
      };
      img.onerror = () => resolve(e.target?.result as string);
      img.src = e.target?.result as string;
    };
    reader.onerror = reject;
    reader.readAsDataURL(blobOrFile);
  });
}

/**
 * Attempts to upload to Supabase storage bucket, and seamlessly falls back to compressed base64 if storage is unavailable or RLS fails.
 */
export async function uploadImageWithFallback({
  bucket,
  path,
  fileOrBlob,
  maxWidth = 400,
  maxHeight = 400,
  quality = 0.85,
}: {
  bucket: string;
  path: string;
  fileOrBlob: File | Blob;
  maxWidth?: number;
  maxHeight?: number;
  quality?: number;
}): Promise<string> {
  try {
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(path, fileOrBlob, {
        contentType: "image/jpeg",
        upsert: true,
      });

    if (!uploadError && uploadData) {
      const { data } = supabase.storage.from(bucket).getPublicUrl(path);
      if (data?.publicUrl) {
        return data.publicUrl;
      }
    }
    console.warn(
      `Supabase Storage upload to bucket "${bucket}" failed (${uploadError?.message}), seamlessly using optimized image data.`,
    );
  } catch (err: any) {
    console.warn(
      `Supabase Storage exception on bucket "${bucket}", seamlessly using optimized image data:`,
      err?.message,
    );
  }

  // Fallback to compressed base64 data URL
  const dataUrl = await blobToCompressedDataUrl(fileOrBlob, maxWidth, maxHeight, quality);
  return dataUrl;
}
