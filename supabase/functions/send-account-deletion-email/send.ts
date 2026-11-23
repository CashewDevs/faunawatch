// Email settings and Brevo sending for send-account-deletion-email and
// purge-deleted-accounts. Same settings as send-suspension-email (secrets are
// shared by all functions). Nothing secret or personal is logged.

import { brevoRequest, type EmailContent } from "./logic.ts";

const DEFAULT_BREVO_URL = "https://api.brevo.com/v3/smtp/email";

export interface EmailSettings {
  apiKey: string;
  sender: { email: string; name: string };
  replyTo: string | null;
  timeZone: string;
}

/** A usable IANA time zone, else UTC. */
function timeZoneOrUtc(value: string | undefined, label: string): string {
  const zone = value?.trim();
  if (!zone) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: zone });
    return zone;
  } catch {
    console.error(`${label}: EMAIL_TIME_ZONE is not valid, using UTC`);
    return "UTC";
  }
}

/** The Brevo settings, or null when BREVO_API_KEY or the sender is missing. */
export function emailSettings(label: string): EmailSettings | null {
  const apiKey = Deno.env.get("BREVO_API_KEY");
  const senderAddress = Deno.env.get("EMAIL_SENDER_ADDRESS")?.trim();
  if (!apiKey || !senderAddress) return null;
  return {
    apiKey,
    sender: {
      email: senderAddress,
      name: Deno.env.get("EMAIL_SENDER_NAME")?.trim() || "FaunaWatch",
    },
    replyTo: Deno.env.get("EMAIL_REPLY_TO")?.trim() || null,
    timeZone: timeZoneOrUtc(Deno.env.get("EMAIL_TIME_ZONE"), label),
  };
}

export type SendResult =
  | { ok: true }
  | { ok: false; status?: number; code: string };

/** Sends one email through Brevo. Never throws. */
export async function sendEmail(
  settings: EmailSettings,
  to: { email: string; name: string | null },
  content: EmailContent,
  label: string,
): Promise<SendResult> {
  let response: Response;
  try {
    response = await fetch(Deno.env.get("BREVO_API_URL") || DEFAULT_BREVO_URL, {
      method: "POST",
      headers: {
        "api-key": settings.apiKey,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify(
        brevoRequest(settings.sender, to, content, settings.replyTo),
      ),
    });
  } catch {
    console.error(`${label}: could not reach Brevo`);
    return { ok: false, code: "unreachable" };
  }
  if (!response.ok) {
    // Brevo's error code (e.g. unauthorized, invalid_parameter) says what to
    // fix and contains nothing personal.
    const body = await response.json().catch(() => null);
    const code = typeof body?.code === "string" ? body.code : "unknown";
    console.error(`${label}: Brevo refused (${response.status}, ${code})`);
    return { ok: false, status: response.status, code };
  }
  await response.body?.cancel();
  return { ok: true };
}

/** Constant-time string comparison. */
export function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

/** True when the request carries the shared x-webhook-secret. */
export function hasWebhookSecret(request: Request): boolean {
  const secret = Deno.env.get("WEBHOOK_SECRET");
  const supplied = request.headers.get("x-webhook-secret") ?? "";
  return !!secret && safeEqual(supplied, secret);
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
