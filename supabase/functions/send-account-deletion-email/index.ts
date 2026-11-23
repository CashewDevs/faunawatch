// send-account-deletion-email: emails a user when they ask to delete their
// account ("will be deleted on …") and when they keep it ("restored"),
// through Brevo's transactional email API.
//
// Triggered by a Supabase Database Webhook on public.account_deletions
// (INSERT and UPDATE). The "deleted" email is sent by purge-deleted-accounts.
// See README.md in this folder for setup.
//
// Environment (the same as send-suspension-email):
//   WEBHOOK_SECRET        shared secret the webhook sends in x-webhook-secret
//   BREVO_API_KEY         Brevo API key
//   EMAIL_SENDER_ADDRESS  the sender verified in Brevo
//   EMAIL_SENDER_NAME     optional, default "FaunaWatch"
//   EMAIL_REPLY_TO        optional reply address
//   EMAIL_TIME_ZONE       optional IANA zone for dates, default "UTC"
//   BREVO_API_URL         optional, for local testing only
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  provided by Supabase
//
// Nothing secret or personal (keys, email addresses, names) is logged.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  deletionEmailKind,
  displayName,
  restoredEmail,
  scheduledEmail,
  type WebhookPayload,
} from "./logic.ts";
import { emailSettings, hasWebhookSecret, json, sendEmail } from "./send.ts";

const LABEL = "send-account-deletion-email";

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!hasWebhookSecret(request)) return json({ error: "unauthorized" }, 401);

  let payload: WebhookPayload;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const kind = deletionEmailKind(payload);
  if (!kind) return json({ skipped: "not an email event" });
  const record = payload.record!;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const settings = emailSettings(LABEL);
  if (!supabaseUrl || !serviceKey || !settings) {
    console.error(`${LABEL}: missing configuration`);
    return json({ error: "not configured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const user = await supabase.auth.admin.getUserById(record.user_id);
  if (user.error) {
    console.error(`${LABEL}: user lookup failed`);
    return json({ error: "lookup failed" }, 500);
  }
  const email = user.data.user?.email;
  if (!email) return json({ skipped: "no email address" });

  // A missing profile only drops the name from the greeting.
  const profile = await supabase
    .from("profiles")
    .select("full_name, username, display_name")
    .eq("id", record.user_id)
    .maybeSingle();
  const name = displayName(profile.data);

  const options = { name, timeZone: settings.timeZone, repliesWelcome: false };
  const content = kind === "scheduled"
    ? scheduledEmail(record, options)
    : restoredEmail(options);

  const sent = await sendEmail(settings, { email, name }, content, LABEL);
  if (!sent.ok) {
    return json({ error: "send failed", status: sent.status, code: sent.code }, 502);
  }
  return json({ sent: kind });
});
