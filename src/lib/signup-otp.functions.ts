import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

const emailSchema = z.object({ email: z.string().email().max(320) });
const verifySchema = z.object({
  email: z.string().email().max(320),
  code: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code."),
});

/**
 * Sends a signup verification code to a freshly registered, unconfirmed account.
 * Always returns a neutral result so the endpoint cannot be used to enumerate accounts.
 */
export const sendSignupOtp = createServerFn({ method: "POST" })
  .validator((data) => emailSchema.parse(data))
  .handler(async ({ data }) => {
    const {
      generateOtpCode,
      hashOtpCode,
      sendOtpEmail,
      OTP_TTL_MINUTES,
      OTP_RESEND_COOLDOWN_SECONDS,
    } = await import("./signup-otp.server");
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    const email = data.email.trim().toLowerCase();
    const db = supabaseAdmin as unknown as {
      from: (table: string) => any;
    };

    const { data: existing } = await db
      .from("signup_otps")
      .select("created_at")
      .eq("email", email)
      .maybeSingle();

    if (existing?.created_at) {
      const elapsed = (Date.now() - new Date(existing.created_at).getTime()) / 1000;
      if (elapsed < OTP_RESEND_COOLDOWN_SECONDS) {
        return { sent: true, cooldown: Math.ceil(OTP_RESEND_COOLDOWN_SECONDS - elapsed) };
      }
    }

    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();

    if (!profile?.id) {
      // Unknown account — stay neutral.
      return { sent: true, cooldown: 0 };
    }

    const { data: userResult } = await supabaseAdmin.auth.admin.getUserById(profile.id);
    if (userResult?.user?.email_confirmed_at) {
      return { sent: true, cooldown: 0 };
    }

    const code = generateOtpCode();
    const codeHash = await hashOtpCode(email, code);

    const { error: upsertError } = await db.from("signup_otps").upsert({
      email,
      code_hash: codeHash,
      expires_at: new Date(Date.now() + OTP_TTL_MINUTES * 60_000).toISOString(),
      attempts: 0,
      created_at: new Date().toISOString(),
    });

    if (upsertError) {
      console.error("Failed to store signup OTP:", upsertError);
      throw new Error("Unable to send verification code. Please try again.");
    }

    await sendOtpEmail(email, code);

    return { sent: true, cooldown: 0 };
  });

/** Verifies a signup code and confirms the account's email address. */
export const verifySignupOtp = createServerFn({ method: "POST" })
  .validator((data) => verifySchema.parse(data))
  .handler(async ({ data }) => {
    const { hashOtpCode, OTP_MAX_ATTEMPTS } = await import("./signup-otp.server");
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");

    const email = data.email.trim().toLowerCase();
    const db = supabaseAdmin as unknown as { from: (table: string) => any };

    const { data: record } = await db
      .from("signup_otps")
      .select("code_hash, expires_at, attempts")
      .eq("email", email)
      .maybeSingle();

    const invalid = new Error("Invalid or expired verification code.");

    if (!record) throw invalid;
    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      await db.from("signup_otps").delete().eq("email", email);
      throw new Error("Too many attempts. Please request a new code.");
    }
    if (new Date(record.expires_at).getTime() < Date.now()) {
      await db.from("signup_otps").delete().eq("email", email);
      throw invalid;
    }

    const codeHash = await hashOtpCode(email, data.code);
    if (codeHash !== record.code_hash) {
      await db
        .from("signup_otps")
        .update({ attempts: (record.attempts ?? 0) + 1 })
        .eq("email", email);
      throw invalid;
    }

    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();

    if (!profile?.id) throw invalid;

    const { error: confirmError } = await supabaseAdmin.auth.admin.updateUserById(profile.id, {
      email_confirm: true,
    });

    if (confirmError) {
      console.error("Failed to confirm user email:", confirmError);
      throw new Error("Unable to verify your account. Please try again.");
    }

    await db.from("signup_otps").delete().eq("email", email);

    return { verified: true };
  });
