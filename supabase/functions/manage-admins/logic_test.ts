// Run with: deno test supabase/functions/manage-admins/logic_test.ts
import { assertEquals } from "jsr:@std/assert@1.0.8";
import {
  authErrorCode,
  inviteDecision,
  inviteRedirect,
  normaliseEmail,
  parseRequest,
  pendingDecision,
} from "./logic.ts";

const USER = "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab";

Deno.test("emails are trimmed, lower-cased and checked", () => {
  assertEquals(normaliseEmail("  New.Admin@Example.COM "), "new.admin@example.com");
  for (const bad of ["", "admin", "admin@", "a b@c.d", "@x.com", 42, null]) {
    assertEquals(normaliseEmail(bad), null, String(bad));
  }
  assertEquals(normaliseEmail(`${"a".repeat(250)}@x.co`), null);
});

Deno.test("requests", () => {
  assertEquals(parseRequest({ action: "invite", email: " A@B.co " }), {
    action: "invite",
    email: "a@b.co",
    redirectTo: undefined,
  });
  assertEquals(
    parseRequest({ action: "resend", userId: USER, redirectTo: "https://x/accept-invite" }),
    { action: "resend", userId: USER, redirectTo: "https://x/accept-invite" },
  );
  assertEquals(parseRequest({ action: "cancel", userId: USER }), {
    action: "cancel",
    userId: USER,
    redirectTo: undefined,
  });
  assertEquals(parseRequest({ action: "invite", email: "nope" }), { error: "invalid_email" });
  assertEquals(parseRequest({ action: "cancel", userId: "1; drop" }), {
    error: "invalid_request",
  });
  assertEquals(parseRequest({ action: "remove", userId: USER }), { error: "invalid_request" });
  assertEquals(parseRequest(null), { error: "invalid_request" });
  assertEquals(parseRequest("invite"), { error: "invalid_request" });
});

Deno.test("inviting depends on who already uses the email", () => {
  assertEquals(inviteDecision(null), { step: "invite" });
  assertEquals(inviteDecision("former_admin"), { step: "restore" });
  assertEquals(inviteDecision("admin"), { error: "already_admin" });
  assertEquals(inviteDecision("invited"), { error: "already_invited" });
  // Decided 2026-11-24: app accounts never become admins.
  assertEquals(inviteDecision("account"), { error: "has_account" });
});

Deno.test("resend and cancel only for invitations not yet accepted", () => {
  assertEquals(pendingDecision("invited"), null);
  for (const status of ["admin", "former_admin", "account", null] as const) {
    assertEquals(pendingDecision(status), "not_invited", String(status));
  }
});

Deno.test("the invitation leads to an accept-invite page", () => {
  const fallback = "https://faunawatch-admin.vercel.app/accept-invite";
  assertEquals(inviteRedirect(undefined, fallback), fallback);
  assertEquals(
    inviteRedirect("https://preview.vercel.app/accept-invite", fallback),
    "https://preview.vercel.app/accept-invite",
  );
  assertEquals(
    inviteRedirect("http://localhost:5173/accept-invite", fallback),
    "http://localhost:5173/accept-invite",
  );
  for (const bad of [
    "http://evil.example/accept-invite", // not https
    "https://x.app/login",
    "https://x.app/accept-invite?next=/users",
    "https://x.app/accept-invite#token",
    "javascript:alert(1)",
    "not a url",
  ]) {
    assertEquals(inviteRedirect(bad, fallback), fallback, bad);
  }
});

Deno.test("Auth errors become our codes, never Supabase's text", () => {
  assertEquals(authErrorCode({ status: 429, code: "over_email_send_rate_limit" }), "rate_limited");
  assertEquals(authErrorCode({ status: 422, code: "email_exists" }), "has_account");
  assertEquals(authErrorCode({ status: 500, code: "unexpected_failure" }), "failed");
  assertEquals(authErrorCode(null), "failed");
});
