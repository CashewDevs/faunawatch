// purge-deleted-accounts: permanently deletes the accounts whose 7 days are
// up, then emails each person that their account has been deleted.
//
// Called every hour by a Supabase Cron job (POST with the x-webhook-secret
// header). See README.md in this folder for setup.
//
// For each due account (public.due_account_deletions(), admins never
// included), in this order:
//   1. reads the email address and name (gone after step 3),
//   2. removes its files (public.account_storage_objects()) through the
//      Storage API,
//   3. deletes the sign-in account; "on delete cascade" removes the profile,
//      reports, comments, chats, notifications and the account_deletions row,
//   4. sends the "deleted" email.
// If step 1, 2 or 3 fails, the account is left for the next run.
//
// Environment: the same as send-account-deletion-email. Without the Brevo
// settings accounts are still deleted on time; only the email is skipped.
//
// Nothing secret or personal (keys, ids, email addresses, names) is logged.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import { deletedEmail, displayName } from "../send-account-deletion-email/logic.ts";
import {
  type EmailSettings,
  emailSettings,
  hasWebhookSecret,
  json,
  sendEmail,
} from "../send-account-deletion-email/send.ts";
import {
  ACCOUNTS_PER_RUN,
  type PurgeOutcome,
  removalBatches,
  type StorageObject,
  summarize,
} from "./logic.ts";

const LABEL = "purge-deleted-accounts";

async function purgeOne(
  supabase: SupabaseClient,
  settings: EmailSettings | null,
  userId: string,
): Promise<PurgeOutcome> {
  // 1. Who to email, read while the account still exists.
  const user = await supabase.auth.admin.getUserById(userId);
  if (user.error) {
    console.error(`${LABEL}: user lookup failed`);
    return "failed";
  }
  const email = user.data.user?.email ?? null;
  const profile = await supabase
    .from("profiles")
    .select("full_name, username, display_name")
    .eq("id", userId)
    .maybeSingle();
  const name = displayName(profile.data);

  // 2. Files.
  const objects = await supabase.rpc("account_storage_objects", {
    p_user_id: userId,
  });
  if (objects.error) {
    console.error(`${LABEL}: listing files failed`);
    return "failed";
  }
  for (const [bucket, names] of removalBatches(objects.data as StorageObject[])) {
    const removed = await supabase.storage.from(bucket).remove(names);
    if (removed.error) {
      console.error(`${LABEL}: removing files failed`);
      return "failed";
    }
  }

  // 3. The account, and with it every row.
  const deleted = await supabase.auth.admin.deleteUser(userId);
  if (deleted.error) {
    console.error(`${LABEL}: deleting the account failed`);
    return "failed";
  }

  // 4. The email.
  if (!email || !settings) return "deleted";
  const sent = await sendEmail(
    settings,
    { email, name },
    deletedEmail({ name, timeZone: settings.timeZone, repliesWelcome: false }),
    LABEL,
  );
  return sent.ok ? "deleted" : "deleted_no_email";
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
  if (!hasWebhookSecret(request)) return json({ error: "unauthorized" }, 401);
  await request.body?.cancel();

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error(`${LABEL}: missing configuration`);
    return json({ error: "not configured" }, 500);
  }
  const settings = emailSettings(LABEL);
  if (!settings) console.error(`${LABEL}: Brevo not configured, no emails`);

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const due = await supabase.rpc("due_account_deletions", {
    p_limit: ACCOUNTS_PER_RUN,
  });
  if (due.error) {
    console.error(`${LABEL}: reading due accounts failed`);
    return json({ error: "lookup failed" }, 500);
  }

  const outcomes: PurgeOutcome[] = [];
  for (const row of (due.data ?? []) as Array<{ user_id: string }>) {
    outcomes.push(await purgeOne(supabase, settings, row.user_id));
  }
  const summary = summarize(outcomes);
  if (summary.due > 0) console.log(`${LABEL}: ${JSON.stringify(summary)}`);
  return json(summary);
});
