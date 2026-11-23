// Run with: deno test supabase/functions/send-suspension-email/logic_test.ts
import {
  assert,
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "jsr:@std/assert@1.0.8";
import {
  brevoRequest,
  categoryLabel,
  displayName,
  durationText,
  emailKind,
  escapeHtml,
  formatDate,
  LOGO_URL,
  reactivatedEmail,
  type SanctionRecord,
  suspendedEmail,
} from "./logic.ts";

const NOW = Date.parse("2026-11-23T12:00:00Z");

const sevenDays: SanctionRecord = {
  id: "s1",
  user_id: "u1",
  reason: "Posting ads in comments",
  category: "spam",
  level: "restricted",
  created_at: "2026-11-23T11:40:00Z",
  ends_at: "2026-11-30T11:40:00Z",
  lifted_at: null,
};

const untilLifted: SanctionRecord = {
  ...sevenDays,
  id: "s2",
  reason: "Abusive messages to other users",
  category: "harassment",
  level: "locked",
  ends_at: null,
};

const options = { name: "Sam", timeZone: "UTC", repliesWelcome: false };

Deno.test("a new suspension in force sends the suspended email", () => {
  assertEquals(
    emailKind({ type: "INSERT", table: "user_sanctions", record: sevenDays }, NOW),
    "suspended",
  );
  assertEquals(emailKind({ type: "INSERT", record: untilLifted }, NOW), "suspended");
});

Deno.test("a suspension inserted already over or lifted sends nothing", () => {
  const over = { ...sevenDays, ends_at: "2026-11-01T00:00:00Z" };
  const lifted = { ...sevenDays, lifted_at: "2026-11-23T11:50:00Z" };
  assertEquals(emailKind({ type: "INSERT", record: over }, NOW), null);
  assertEquals(emailKind({ type: "INSERT", record: lifted }, NOW), null);
});

Deno.test("lifting early sends the reactivated email", () => {
  const lifted = { ...sevenDays, lifted_at: "2026-11-25T08:00:00Z" };
  assertEquals(
    emailKind({ type: "UPDATE", record: lifted, old_record: sevenDays }, NOW),
    "reactivated",
  );
  const liftedForever = { ...untilLifted, lifted_at: "2027-03-01T08:00:00Z" };
  assertEquals(
    emailKind({ type: "UPDATE", record: liftedForever, old_record: untilLifted }, NOW),
    "reactivated",
  );
});

Deno.test("other updates, deletes and tables send nothing", () => {
  // Lifted after it had already ended.
  const late = { ...sevenDays, lifted_at: "2026-12-05T00:00:00Z" };
  assertEquals(emailKind({ type: "UPDATE", record: late, old_record: sevenDays }, NOW), null);
  // Already lifted before.
  const lifted = { ...sevenDays, lifted_at: "2026-11-25T08:00:00Z" };
  assertEquals(emailKind({ type: "UPDATE", record: lifted, old_record: lifted }, NOW), null);
  // Not lifted.
  assertEquals(
    emailKind({ type: "UPDATE", record: sevenDays, old_record: sevenDays }, NOW),
    null,
  );
  assertEquals(emailKind({ type: "UPDATE", record: lifted, old_record: null }, NOW), null);
  assertEquals(emailKind({ type: "DELETE", record: null, old_record: sevenDays }, NOW), null);
  assertEquals(
    emailKind({ type: "INSERT", table: "notifications", record: sevenDays }, NOW),
    null,
  );
  assertEquals(emailKind({ type: "INSERT", record: null }, NOW), null);
});

Deno.test("categories, durations and dates", () => {
  assertEquals(categoryLabel("scam_or_impersonation"), "Scam or impersonation");
  assertEquals(categoryLabel(null), null);
  assertEquals(categoryLabel("nope"), null);
  assertEquals(durationText(sevenDays), "7 days");
  assertEquals(
    durationText({ ...sevenDays, ends_at: "2026-11-24T11:40:00Z" }),
    "1 day",
  );
  assertEquals(durationText(untilLifted), null);
  assertEquals(formatDate("2026-11-30T11:40:00Z", "UTC"), "30 Nov 2026, 11:40 AM (UTC)");
  assertEquals(
    formatDate("2026-11-30T11:40:00Z", "Asia/Manila"),
    "30 Nov 2026, 7:40 PM (Asia/Manila)",
  );
});

Deno.test("restricted suspension email: reason, message, end, what is blocked", () => {
  const email = suspendedEmail(sevenDays, options);
  assertEquals(email.subject, "Your FaunaWatch account has been suspended");
  assertStringIncludes(email.text, "Hi Sam,");
  assertStringIncludes(
    email.text,
    "suspended for 7 days, until 30 Nov 2026, 11:40 AM (UTC).",
  );
  assertStringIncludes(email.text, "Reason: Spam");
  assertStringIncludes(email.text, "Message from the FaunaWatch team: Posting ads in comments");
  assertStringIncludes(email.text, "you can't post reports, comment, like posts");
  assertStringIncludes(email.text, "restored automatically");
  assertFalse(email.text.includes("reply to this email"));
  assertStringIncludes(email.html, "Posting ads in comments");
});

Deno.test("locked suspension email until lifted", () => {
  const email = suspendedEmail(untilLifted, { ...options, name: null, repliesWelcome: true });
  assertStringIncludes(email.text, "Hi,\n");
  assertStringIncludes(email.text, "suspended until an admin lifts the suspension.");
  assertStringIncludes(email.text, "Reason: Harassment or bullying");
  assertStringIncludes(email.text, "Ends: When an admin lifts the suspension");
  assertStringIncludes(email.text, "You can't use FaunaWatch until the suspension ends.");
  assertStringIncludes(email.text, "We will email you when your account is active again.");
  assertStringIncludes(email.text, "reply to this email");
});

Deno.test("older suspensions without a category still read well", () => {
  const email = suspendedEmail({ ...sevenDays, category: null, level: null }, options);
  assertStringIncludes(email.text, "Reason: Breaking the FaunaWatch community rules");
  assertStringIncludes(email.text, "you can't post reports");
});

Deno.test("the admin's message and the name are escaped in HTML", () => {
  const email = suspendedEmail(
    { ...sevenDays, reason: `<script>alert("x")</script> & more` },
    { ...options, name: "<b>Sam</b>" },
  );
  assertFalse(email.html.includes("<script>"));
  assertFalse(email.html.includes("<b>Sam</b>"));
  assertStringIncludes(email.html, "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; more");
  assertEquals(escapeHtml(`'`), "&#39;");
});

Deno.test("reactivated email", () => {
  const email = reactivatedEmail(options);
  assertEquals(email.subject, "Your FaunaWatch account is active again");
  assertStringIncludes(email.text, "An admin lifted the suspension");
  assertStringIncludes(email.text, "send messages again");
});

Deno.test("both emails use the FaunaWatch layout", () => {
  assertEquals(
    LOGO_URL,
    "https://faunawatch-admin.vercel.app/email/faunawatch-logo.png",
  );
  for (const email of [suspendedEmail(sevenDays, options), reactivatedEmail(options)]) {
    // The logo on the blue header, and the footer.
    assertStringIncludes(email.html, `<img src="${LOGO_URL}"`);
    assertStringIncludes(email.html, `alt="FaunaWatch"`);
    assertStringIncludes(email.html, "background:#1a5dc9");
    assertStringIncludes(email.html, "Mapping life, one sighting at a time.");
    // The subject is the page title and the heading.
    assertStringIncludes(email.html, `<title>${email.subject}</title>`);
    assertStringIncludes(email.html, `">${email.subject}</h1>`);
  }
  // The inbox preview line is the first sentence of the email.
  assertStringIncludes(
    reactivatedEmail(options).html,
    `opacity:0;">An admin lifted the suspension on your FaunaWatch account.</div>`,
  );
});

Deno.test("Brevo request", () => {
  const content = reactivatedEmail(options);
  assertEquals(
    brevoRequest(
      { email: "team@example.com", name: "FaunaWatch" },
      { email: "sam@example.com", name: "Sam" },
      content,
      null,
    ),
    {
      sender: { email: "team@example.com", name: "FaunaWatch" },
      to: [{ email: "sam@example.com", name: "Sam" }],
      subject: content.subject,
      htmlContent: content.html,
      textContent: content.text,
      tags: ["account-suspension"],
    },
  );
  const withReply = brevoRequest(
    { email: "team@example.com", name: "FaunaWatch" },
    { email: "sam@example.com", name: null },
    content,
    "help@example.com",
  );
  assertEquals(withReply.to, [{ email: "sam@example.com" }]);
  assertEquals(withReply.replyTo, { email: "help@example.com" });
});

Deno.test("display name prefers full name, then username", () => {
  assertEquals(displayName({ full_name: " Sam Cruz ", username: "sam" }), "Sam Cruz");
  assertEquals(displayName({ full_name: "  ", username: "sam" }), "sam");
  assertEquals(displayName({ display_name: "Old" }), "Old");
  assertEquals(displayName(null), null);
  assert(displayName({ full_name: "x".repeat(200) })!.length === 80);
});
