/**
 * Server-only helpers for the custom signup verification code (OTP) flow.
 * Codes are generated here, stored hashed, and delivered through Resend.
 */

const GATEWAY_URL = "https://connector-gateway.lovable.dev/resend";

/** Sender identity — must be a domain verified in Resend. */
export const OTP_FROM = "Noble Gain <no-reply@noblegain.bytsphere.buzz>";

export const OTP_TTL_MINUTES = 10;
export const OTP_MAX_ATTEMPTS = 5;
export const OTP_RESEND_COOLDOWN_SECONDS = 45;

export function generateOtpCode(): string {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String((bytes[0] ?? 0) % 1_000_000).padStart(6, "0");
}

export async function hashOtpCode(email: string, code: string): Promise<string> {
  const data = new TextEncoder().encode(`${email.trim().toLowerCase()}:${code}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function renderOtpEmail(code: string): string {
  return `<!DOCTYPE html>
<html lang="en">
  <head><meta charset="UTF-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /><title>Verify your Noble Gain account</title></head>
  <body style="margin:0;padding:0;background:#f1efe9;font-family:Inter,Arial,sans-serif;color:#102026;">
    <div style="width:100%;max-width:620px;margin:36px auto;background:#fffdf9;border-radius:28px;overflow:hidden;border:1px solid rgba(16,32,38,0.08);">
      <div style="padding:28px 32px 18px;background:linear-gradient(135deg,#0f2a30 0%,#183d45 52%,#0b1f26 100%);">
        <span style="font-size:24px;font-weight:900;letter-spacing:0.08em;color:#ffffff;text-transform:uppercase;">Noble Gain</span>
      </div>
      <div style="padding:34px 32px 24px;">
        <div style="font-size:11px;font-weight:800;letter-spacing:0.18em;text-transform:uppercase;color:#7a6a45;margin-bottom:16px;">Account Verification</div>
        <h1 style="margin:0 0 12px;font-size:30px;line-height:1.15;color:#102026;">Welcome to your rewards vault.</h1>
        <p style="margin:0 0 18px;font-size:16px;line-height:1.7;color:rgba(16,32,38,0.8);">
          Your account is almost ready. Use the secure code below to verify your email and unlock your welcome reward experience.
        </p>
        <div style="margin:28px 0 20px;background:rgba(230,193,122,0.16);border:1px solid rgba(15,42,48,0.1);border-radius:22px;padding:26px 20px;text-align:center;">
          <div style="font-size:12px;font-weight:800;letter-spacing:0.16em;text-transform:uppercase;color:rgba(16,32,38,0.56);">One-time code</div>
          <div style="margin-top:14px;font-size:38px;line-height:1;letter-spacing:0.28em;font-weight:900;color:#102026;">${code}</div>
        </div>
        <p style="margin:0;font-size:16px;line-height:1.7;color:rgba(16,32,38,0.8);">
          This code expires in ${OTP_TTL_MINUTES} minutes. If you didn't create a Noble Gain account, you can ignore this message.
        </p>
      </div>
      <div style="padding:22px 32px 32px;color:rgba(16,32,38,0.64);font-size:12px;text-align:center;">
        © ${new Date().getFullYear()} Noble Gain. Turn your time into real rewards.
      </div>
    </div>
  </body>
</html>`;
}

/** Sends the verification code email through the Resend connector gateway. */
export async function sendOtpEmail(to: string, code: string): Promise<void> {
  const lovableKey = process.env["LOVABLE_API_KEY"];
  const resendKey = process.env["RESEND_API_KEY"];

  if (!lovableKey) throw new Error("LOVABLE_API_KEY is not configured");
  if (!resendKey) throw new Error("RESEND_API_KEY is not configured");

  const response = await fetch(`${GATEWAY_URL}/emails`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${lovableKey}`,
      "X-Connection-Api-Key": resendKey,
    },
    body: JSON.stringify({
      from: OTP_FROM,
      to: [to],
      subject: `${code} is your Noble Gain verification code`,
      html: renderOtpEmail(code),
      text: `Your Noble Gain verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error(`Resend request failed [${response.status}]: ${body}`);
    throw new Error(`Email delivery failed [${response.status}]: ${body}`);
  }
}
