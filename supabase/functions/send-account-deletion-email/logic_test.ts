// Run with: deno test supabase/functions/send-account-deletion-email/logic_test.ts
import {
  assert,
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "jsr:@std/assert@1.0.8";
import { LOGO_URL } from "../send-suspension-email/logic.ts";
import {
  brevoRequest,
  type DeletionRecord,
  deletedEmail,
  deletionEmailKind,
  restoredEmail,
  scheduledEmail,
} from "./logic.ts";

const waiting: DeletionRecord = {
  user_id: "u1",
  requested_at: "2026-11-24T07:40:00Z",
  delete_after: "2026-12-01T07:40:00Z",
  cancelled_at: null,
};
const kept: DeletionRecord = { ...waiting, cancelled_at: "2026-11-26T01:00:00Z" };

const options = { name: "Alice", timeZone: "Asia/Manila", repliesWelcome: false };

Deno.test("asking to delete sends the scheduled email", () => {
  assertEquals(
    deletionEmailKind({ type: "INSERT", table: "account_deletions", record: waiting }),
    "scheduled",
  );
});

Deno.test("asking again after keeping sends the scheduled email", () => {
  assertEquals(
    deletionEmailKind({
      type: "UPDATE",
      table: "account_deletions",
      record: waiting,
      old_record: kept,
    }),
    "scheduled",
  );
});

Deno.test("keeping the account sends the restored email", () => {
  assertEquals(
    deletionEmailKind({
      type: "UPDATE",
      table: "account_deletions",
      record: kept,
      old_record: waiting,
    }),
    "restored",
  );
});

Deno.test("nothing for other events", () => {
  // The final delete: purge-deleted-accounts sends that email itself.
  assertEquals(
    deletionEmailKind({ type: "DELETE", table: "account_deletions", record: null, old_record: waiting }),
    null,
  );
  // An update that changes nothing about waiting.
  assertEquals(
    deletionEmailKind({ type: "UPDATE", table: "account_deletions", record: waiting, old_record: waiting }),
    null,
  );
  assertEquals(
    deletionEmailKind({ type: "UPDATE", table: "account_deletions", record: kept, old_record: kept }),
    null,
  );
  // Inserted already cancelled, missing pieces, other tables.
  assertEquals(deletionEmailKind({ type: "INSERT", record: kept }), null);
  assertEquals(
    deletionEmailKind({ type: "INSERT", record: { ...waiting, delete_after: null } }),
    null,
  );
  assertEquals(deletionEmailKind({ type: "UPDATE", record: kept }), null);
  assertEquals(deletionEmailKind({ type: "INSERT", record: { ...waiting, user_id: "" } }), null);
  assertEquals(
    deletionEmailKind({ type: "INSERT", table: "user_sanctions", record: waiting }),
    null,
  );
});

Deno.test("scheduled email: date in the time zone, how to keep it", () => {
  const email = scheduledEmail(waiting, options);
  assertEquals(email.subject, "Your FaunaWatch account will be deleted");
  assertStringIncludes(email.text, "Hi Alice,");
  assertStringIncludes(email.text, "Deleted on: 1 Dec 2026, 3:40 PM (Asia/Manila)");
  assertStringIncludes(email.text, '"Keep my account"');
  assertStringIncludes(email.text, "other people can't see your profile");
  assertStringIncludes(email.text, "permanently deleted");
  assertStringIncludes(email.text, "change your password");
});

Deno.test("restored email", () => {
  const email = restoredEmail({ ...options, name: null });
  assertEquals(email.subject, "Your FaunaWatch account is restored");
  assertStringIncludes(email.text, "Hi,\n");
  assertStringIncludes(email.text, "won't be deleted");
  assertStringIncludes(email.text, "Change your password");
});

Deno.test("deleted email", () => {
  const email = deletedEmail(options);
  assertEquals(email.subject, "Your FaunaWatch account has been deleted");
  assertStringIncludes(email.text, "permanently deleted");
  assertStringIncludes(email.text, "create a new account");
  assertFalse(email.text.includes("Keep my account"));
});

Deno.test("all three use the FaunaWatch layout and escape names", () => {
  const evil = { ...options, name: "<b>Eve</b>" };
  for (const email of [scheduledEmail(waiting, evil), restoredEmail(evil), deletedEmail(evil)]) {
    assertStringIncludes(email.html, LOGO_URL);
    assertStringIncludes(email.html, "background:#1a5dc9");
    assertStringIncludes(email.html, "Hi &lt;b&gt;Eve&lt;/b&gt;,");
    assertFalse(email.html.includes("<b>Eve</b>"));
  }
});

Deno.test("Brevo request is tagged for account deletion", () => {
  const body = brevoRequest(
    { email: "team@example.com", name: "FaunaWatch" },
    { email: "alice@example.com", name: "Alice" },
    deletedEmail(options),
    null,
  );
  assertEquals(body.tags, ["account-deletion"]);
  assertEquals(body.to, [{ email: "alice@example.com", name: "Alice" }]);
  assertEquals(body.subject, "Your FaunaWatch account has been deleted");
  assert(!("replyTo" in body));
});
