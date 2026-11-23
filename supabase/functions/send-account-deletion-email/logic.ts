// Pure helpers for the account deletion emails: no network, no environment
// access, so they are easy to unit test (see logic_test.ts). Also used by
// purge-deleted-accounts for the "deleted" email.
//
// The layout is the shared FaunaWatch email design from
// send-suspension-email/logic.ts.

import {
  brevoRequest as suspensionBrevoRequest,
  type EmailContent,
  type EmailOptions,
  formatDate,
  render,
} from "../send-suspension-email/logic.ts";

export { displayName, type EmailContent, type EmailOptions } from "../send-suspension-email/logic.ts";

/** A row of public.account_deletions, as sent by the Database Webhook. */
export interface DeletionRecord {
  user_id: string;
  requested_at?: string | null;
  delete_after?: string | null;
  cancelled_at?: string | null;
}

/** The Database Webhook payload for public.account_deletions. */
export interface WebhookPayload {
  type: string; // INSERT | UPDATE | DELETE
  table?: string;
  schema?: string;
  record?: DeletionRecord | null;
  old_record?: DeletionRecord | null;
}

export type DeletionEmailKind = "scheduled" | "restored";

/**
 * Which email this event needs:
 *
 * - INSERT of a waiting deletion, or an UPDATE that starts waiting again
 *   (asked again after keeping the account): "scheduled".
 * - UPDATE that sets cancelled_at ("Keep my account"): "restored".
 * - Anything else (DELETE when the account is finally deleted, other
 *   tables): nothing. purge-deleted-accounts sends the "deleted" email.
 */
export function deletionEmailKind(payload: WebhookPayload): DeletionEmailKind | null {
  if (payload.table !== undefined && payload.table !== "account_deletions") {
    return null;
  }
  const record = payload.record;
  if (!record || typeof record.user_id !== "string" || !record.user_id) return null;
  const waiting = record.cancelled_at == null;

  if (payload.type === "INSERT") {
    return waiting && record.delete_after ? "scheduled" : null;
  }
  if (payload.type === "UPDATE") {
    const old = payload.old_record;
    if (!old) return null;
    const wasWaiting = old.cancelled_at == null;
    if (!wasWaiting && waiting && record.delete_after) return "scheduled";
    if (wasWaiting && !waiting) return "restored";
  }
  return null;
}

const HIDDEN =
  "Until then, other people can't see your profile, posts, comments or chats.";
const EVERYTHING =
  "your profile, reports, photos, comments, chats and notifications";

/** "Your FaunaWatch account will be deleted on …" */
export function scheduledEmail(
  record: DeletionRecord,
  options: EmailOptions,
): EmailContent {
  const date = formatDate(record.delete_after!, options.timeZone);
  return render(
    options,
    "Your FaunaWatch account will be deleted",
    `We got your request to delete your FaunaWatch account. It will be deleted on ${date}.`,
    [{ label: "Deleted on", value: date }],
    [
      HIDDEN,
      'Changed your mind? Sign in to the FaunaWatch app before then and tap "Keep my account". Everything comes back.',
      `After that date, ${EVERYTHING} are permanently deleted. This can't be undone.`,
      "Didn't ask for this? Sign in, keep your account and change your password.",
    ],
  );
}

/** "Your FaunaWatch account is restored" ("Keep my account"). */
export function restoredEmail(options: EmailOptions): EmailContent {
  return render(
    options,
    "Your FaunaWatch account is restored",
    "You signed in and kept your FaunaWatch account, so it won't be deleted.",
    [],
    [
      "Your profile, posts, comments and chats are visible to others again.",
      "Didn't do this? Change your password in the app (Settings › Change password).",
    ],
  );
}

/** "Your FaunaWatch account has been deleted" (sent after the delete). */
export function deletedEmail(options: EmailOptions): EmailContent {
  return render(
    options,
    "Your FaunaWatch account has been deleted",
    "Your FaunaWatch account has been permanently deleted, as you asked 7 days ago.",
    [],
    [
      `This includes ${EVERYTHING}.`,
      "You're welcome to create a new account with this email address at any time.",
      "Thank you for helping map wildlife with FaunaWatch.",
    ],
  );
}

/** The body of Brevo's POST /v3/smtp/email, tagged for these emails. */
export function brevoRequest(
  sender: { email: string; name: string },
  to: { email: string; name: string | null },
  content: EmailContent,
  replyTo: string | null,
): Record<string, unknown> {
  return {
    ...suspensionBrevoRequest(sender, to, content, replyTo),
    // Lets these emails be found in Brevo's transactional logs.
    tags: ["account-deletion"],
  };
}
