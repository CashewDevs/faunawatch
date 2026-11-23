// Pure helpers for send-suspension-email: no network, no environment access,
// so they are easy to unit test (see logic_test.ts).

/** A row of public.user_sanctions, as sent by the Database Webhook. */
export interface SanctionRecord {
  id: string;
  user_id: string;
  reason?: string | null;
  category?: string | null;
  level?: string | null;
  created_at?: string | null;
  ends_at?: string | null;
  lifted_at?: string | null;
  // created_by (the admin) is also sent; it is never used or shown.
}

/** The Database Webhook payload for public.user_sanctions. */
export interface WebhookPayload {
  type: string; // INSERT | UPDATE | DELETE
  table?: string;
  schema?: string;
  record?: SanctionRecord | null;
  old_record?: SanctionRecord | null;
}

export type EmailKind = "suspended" | "reactivated";

function time(value: string | null | undefined): number | null {
  if (!value) return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

/**
 * Which email this event needs, using the same rules as the database's
 * notify_user_sanction() trigger:
 *
 * - INSERT of a suspension in force now: "suspended".
 * - UPDATE that lifts a suspension still in force (an admin reactivated the
 *   user early): "reactivated".
 * - Anything else (a suspension that simply ran out, other updates, DELETE,
 *   other tables): nothing.
 */
export function emailKind(
  payload: WebhookPayload,
  now: number = Date.now(),
): EmailKind | null {
  if (payload.table !== undefined && payload.table !== "user_sanctions") {
    return null;
  }
  const record = payload.record;
  if (!record || typeof record.id !== "string" || !record.user_id) return null;

  if (payload.type === "INSERT") {
    const ends = time(record.ends_at);
    const inForce = record.lifted_at == null && (ends === null || ends > now);
    return inForce ? "suspended" : null;
  }
  if (payload.type === "UPDATE") {
    const old = payload.old_record;
    if (!old || old.lifted_at != null || record.lifted_at == null) return null;
    const lifted = time(record.lifted_at);
    const ends = time(old.ends_at);
    if (lifted === null) return null;
    return ends === null || ends > lifted ? "reactivated" : null;
  }
  return null;
}

/** Must match public.suspension_category_label() and the app. */
const CATEGORY_LABELS: Record<string, string> = {
  spam: "Spam",
  misleading_reports: "Fake or misleading reports",
  inappropriate_content: "Inappropriate content",
  harassment: "Harassment or bullying",
  hate_or_threats: "Hate speech or threats",
  scam_or_impersonation: "Scam or impersonation",
  other: "Other",
};

/** Null for suspensions without a category (made by older admin sites). */
export function categoryLabel(category: string | null | undefined): string | null {
  return category ? CATEGORY_LABELS[category] ?? null : null;
}

/** "7 days", rounded like the in-app notification; null without an end. */
export function durationText(record: SanctionRecord): string | null {
  const start = time(record.created_at);
  const end = time(record.ends_at);
  if (start === null || end === null) return null;
  const days = Math.max(1, Math.round((end - start) / 86_400_000));
  return days === 1 ? "1 day" : `${days} days`;
}

/** "30 Nov 2026, 7:40 PM (Asia/Manila)" in [timeZone]. */
export function formatDate(value: string, timeZone: string): string {
  const date = new Date(value);
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone,
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
  const clock = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(date);
  // Newer ICU puts a narrow no-break space before AM/PM; keep plain spaces.
  const plain = (text: string) => text.replace(/\s+/g, " ");
  return `${plain(parts)}, ${plain(clock)} (${timeZone})`;
}

/** Escapes text for HTML element content and attribute values. */
export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export interface EmailContent {
  subject: string;
  text: string;
  html: string;
}

export interface EmailOptions {
  /** The user's name, or null to greet without one. */
  name: string | null;
  timeZone: string;
  /** Adds "reply to this email" when replies are read. */
  repliesWelcome: boolean;
}

const RESTRICTED_EFFECT =
  "You can still open FaunaWatch and browse, but you can't post reports, " +
  "comment, like posts, send messages or edit your profile until the " +
  "suspension ends.";
const LOCKED_EFFECT =
  "You can't use FaunaWatch until the suspension ends. If you open the app, " +
  "you will see the reason and the end date.";

/** One block of the email: a label and its value. */
interface Row {
  label: string;
  value: string;
}

function render(
  options: EmailOptions,
  subject: string,
  intro: string,
  rows: Row[],
  closing: string[],
): EmailContent {
  const greeting = options.name ? `Hi ${options.name},` : "Hi,";
  const reply = options.repliesWelcome
    ? ["If you think this is a mistake, reply to this email."]
    : [];
  const paragraphs = [...closing, ...reply];

  const text = [
    greeting,
    "",
    intro,
    "",
    ...rows.map((row) => `${row.label}: ${row.value}`),
    ...(rows.length ? [""] : []),
    ...paragraphs.flatMap((p) => [p, ""]),
    "The FaunaWatch team",
  ].join("\n");

  const p = (inner: string) =>
    `<p style="margin:0 0 16px;font-size:15px;line-height:1.5;color:#0f172a">${inner}</p>`;
  const rowHtml = rows
    .map((row) =>
      `<tr><td style="padding:8px 0;vertical-align:top">` +
      `<div style="font-size:12px;font-weight:700;color:#64748b">${escapeHtml(row.label)}</div>` +
      `<div style="font-size:15px;line-height:1.45;color:#0f172a;white-space:pre-wrap">${escapeHtml(row.value)}</div>` +
      `</td></tr>`
    )
    .join("");
  const html = [
    `<!doctype html><html><body style="margin:0;padding:24px;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif">`,
    `<div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;padding:28px">`,
    `<h1 style="margin:0 0 16px;font-size:20px;color:#0f172a">${escapeHtml(subject)}</h1>`,
    p(escapeHtml(greeting)),
    p(escapeHtml(intro)),
    rows.length
      ? `<table role="presentation" style="width:100%;border-collapse:collapse;margin:0 0 16px;border-top:1px solid #e2e8f0;border-bottom:1px solid #e2e8f0">${rowHtml}</table>`
      : "",
    ...paragraphs.map((text) => p(escapeHtml(text))),
    p("The FaunaWatch team"),
    `</div></body></html>`,
  ].join("");

  return { subject, text, html };
}

/** The "your account has been suspended" email. */
export function suspendedEmail(
  record: SanctionRecord,
  options: EmailOptions,
): EmailContent {
  const duration = durationText(record);
  const ends = record.ends_at ? formatDate(record.ends_at, options.timeZone) : null;
  const length = duration && ends
    ? `for ${duration}, until ${ends}`
    : "until an admin lifts the suspension";

  const rows: Row[] = [];
  rows.push({
    label: "Reason",
    value: categoryLabel(record.category) ?? "Breaking the FaunaWatch community rules",
  });
  const message = record.reason?.trim();
  if (message) rows.push({ label: "Message from the FaunaWatch team", value: message });
  rows.push({ label: "Ends", value: ends ?? "When an admin lifts the suspension" });

  const effect = record.level === "locked" ? LOCKED_EFFECT : RESTRICTED_EFFECT;
  const restored = ends
    ? "Your account is restored automatically when the suspension ends."
    : "We will email you when your account is active again.";

  return render(
    options,
    "Your FaunaWatch account has been suspended",
    `Your FaunaWatch account has been suspended ${length}.`,
    rows,
    [effect, restored],
  );
}

/** The "your account is active again" email (lifted early by an admin). */
export function reactivatedEmail(options: EmailOptions): EmailContent {
  return render(
    options,
    "Your FaunaWatch account is active again",
    "An admin lifted the suspension on your FaunaWatch account.",
    [],
    ["You can post reports, comment, like posts and send messages again."],
  );
}

/** The body of Brevo's POST /v3/smtp/email. */
export function brevoRequest(
  sender: { email: string; name: string },
  to: { email: string; name: string | null },
  content: EmailContent,
  replyTo: string | null,
): Record<string, unknown> {
  return {
    sender,
    to: [to.name ? { email: to.email, name: to.name } : { email: to.email }],
    ...(replyTo ? { replyTo: { email: replyTo } } : {}),
    subject: content.subject,
    htmlContent: content.html,
    textContent: content.text,
    // Lets these emails be found in Brevo's transactional logs.
    tags: ["account-suspension"],
  };
}

/** The best name for the greeting from a profiles row. */
export function displayName(profile: {
  full_name?: string | null;
  username?: string | null;
  display_name?: string | null;
} | null): string | null {
  for (const value of [profile?.full_name, profile?.username, profile?.display_name]) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed.slice(0, 80);
  }
  return null;
}
