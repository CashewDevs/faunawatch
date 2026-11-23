// send-suspension-email: emails a user when they are suspended, and when an
// admin lifts their suspension early, through Brevo's transactional email API.
//
// Triggered by a Supabase Database Webhook on public.user_sanctions (INSERT
// and UPDATE). See README.md in this folder for setup.
//
// Environment:
//   WEBHOOK_SECRET        shared secret the webhook sends in x-webhook-secret
//                         (the same one send-push uses; secrets are shared)
//   BREVO_API_KEY         Brevo API key (SMTP & API > API keys)
//   EMAIL_SENDER_ADDRESS  the sender verified in Brevo
//   EMAIL_SENDER_NAME     optional, default "FaunaWatch"
//   EMAIL_REPLY_TO        optional; when set, replies go there and the email
//                         invites them
//   EMAIL_TIME_ZONE       optional IANA zone for dates, default "UTC"
//   BREVO_API_URL         optional, for local testing only
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  provided by Supabase
//
// Nothing secret or personal (keys, email addresses, names, reasons) is
// logged.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  brevoRequest,
  displayName,
  emailKind,
  reactivatedEmail,
  suspendedEmail,
  type WebhookPayload,
} from "./logic.ts";

const DEFAULT_BREVO_URL = "https://api.brevo.com/v3/smtp/email";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

/** Constant-time string comparison. */
function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  }
  return diff === 0;
}

/** A usable IANA time zone, else UTC. */
function timeZoneOrUtc(value: string | undefined): string {
  const zone = value?.trim();
  if (!zone) return "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: zone });
    return zone;
  } catch {
    console.error("send-suspension-email: EMAIL_TIME_ZONE is not valid, using UTC");
    return "UTC";
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "method not allowed" }, 405);

  const secret = Deno.env.get("WEBHOOK_SECRET");
  const supplied = request.headers.get("x-webhook-secret") ?? "";
  if (!secret || !safeEqual(supplied, secret)) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: WebhookPayload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const kind = emailKind(payload);
  if (!kind) return json({ skipped: "not an email event" });
  const record = payload.record!;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const apiKey = Deno.env.get("BREVO_API_KEY");
  const senderAddress = Deno.env.get("EMAIL_SENDER_ADDRESS")?.trim();
  if (!supabaseUrl || !serviceKey || !apiKey || !senderAddress) {
    console.error("send-suspension-email: missing configuration");
    return json({ error: "not configured" }, 500);
  }
  const senderName = Deno.env.get("EMAIL_SENDER_NAME")?.trim() || "FaunaWatch";
  const replyTo = Deno.env.get("EMAIL_REPLY_TO")?.trim() || null;
  const timeZone = timeZoneOrUtc(Deno.env.get("EMAIL_TIME_ZONE"));

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const user = await supabase.auth.admin.getUserById(record.user_id);
  const email = user.data.user?.email;
  if (user.error) {
    console.error("send-suspension-email: user lookup failed");
    return json({ error: "lookup failed" }, 500);
  }
  if (!email) return json({ skipped: "no email address" });

  // A missing profile only drops the name from the greeting.
  const profile = await supabase
    .from("profiles")
    .select("full_name, username, display_name")
    .eq("id", record.user_id)
    .maybeSingle();
  const name = displayName(profile.data);

  const options = { name, timeZone, repliesWelcome: replyTo !== null };
  const content = kind === "suspended"
    ? suspendedEmail(record, options)
    : reactivatedEmail(options);

  let response: Response;
  try {
    response = await fetch(Deno.env.get("BREVO_API_URL") || DEFAULT_BREVO_URL, {
      method: "POST",
      headers: {
        "api-key": apiKey,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify(
        brevoRequest(
          { email: senderAddress, name: senderName },
          { email, name },
          content,
          replyTo,
        ),
      ),
    });
  } catch {
    console.error("send-suspension-email: could not reach Brevo");
    return json({ error: "send failed" }, 502);
  }
  if (!response.ok) {
    // Brevo's error code (e.g. unauthorized, invalid_parameter) says what to
    // fix and contains nothing personal.
    const body = await response.json().catch(() => null);
    const code = typeof body?.code === "string" ? body.code : "unknown";
    console.error(`send-suspension-email: Brevo refused (${response.status}, ${code})`);
    return json({ error: "send failed", status: response.status, code }, 502);
  }
  await response.body?.cancel();
  return json({ sent: kind });
});
