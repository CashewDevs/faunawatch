// manage-admins: lets an admin invite another admin by email, resend an
// invitation, or cancel one. Called by the admin site (Admins page) with the
// admin's own session. Removing an active admin and listing admins don't
// need this: they are the database functions admin_remove_admin() and
// admin_list_admins().
//
// Invitations use Supabase Auth's "Invite user" email (sent through Brevo,
// in the FaunaWatch design: supabase/templates/invite.html). See README.md.
//
// Environment:
//   ADMIN_SITE_URL  optional, default https://faunawatch-admin.vercel.app;
//                   invitations lead to <ADMIN_SITE_URL>/accept-invite when
//                   the request doesn't say where
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  provided by Supabase
//
// Nothing secret or personal (keys, tokens, email addresses) is logged.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  type AccountStatus,
  authErrorCode,
  type ErrorCode,
  errorStatus,
  inviteDecision,
  inviteRedirect,
  type ManageRequest,
  parseRequest,
  pendingDecision,
} from "./logic.ts";

const DEFAULT_ADMIN_SITE_URL = "https://faunawatch-admin.vercel.app";

// The admin site calls this from the browser. Access needs an admin's
// session token, not cookies, so any origin may ask.
const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

function fail(code: ErrorCode): Response {
  return json({ error: code }, errorStatus[code]);
}

interface Account {
  user_id: string;
  email: string;
  status: AccountStatus;
}

async function accountStatus(
  admin: SupabaseClient,
  by: { email: string } | { userId: string },
): Promise<Account | null> {
  const { data, error } = await admin.rpc(
    "admin_account_status",
    "email" in by ? { p_email: by.email } : { p_user_id: by.userId },
  );
  if (error) throw new Error(`admin_account_status failed (${error.code})`);
  return (data as Account[] | null)?.[0] ?? null;
}

async function grantAccess(admin: SupabaseClient, userId: string): Promise<void> {
  const { error } = await admin.rpc("admin_grant_access", { p_user_id: userId });
  if (error) throw new Error(`admin_grant_access failed (${error.code})`);
}

async function handle(
  admin: SupabaseClient,
  request: ManageRequest,
  redirectTo: string,
): Promise<Response> {
  if (request.action === "invite") {
    const existing = await accountStatus(admin, { email: request.email });
    const decision = inviteDecision(existing?.status ?? null);
    if ("error" in decision) return fail(decision.error);

    if (decision.step === "restore") {
      await grantAccess(admin, existing!.user_id);
      return json({ result: "restored" });
    }

    const { data, error } = await admin.auth.admin.inviteUserByEmail(request.email, {
      redirectTo,
    });
    if (error || !data.user) {
      const code = authErrorCode(error);
      console.error(`manage-admins: invite failed (${error?.status} ${error?.code})`);
      return fail(code);
    }
    try {
      await grantAccess(admin, data.user.id);
    } catch (grantError) {
      // Never leave an invited account that isn't an admin.
      await admin.auth.admin.deleteUser(data.user.id);
      throw grantError;
    }
    return json({ result: "invited" });
  }

  const target = await accountStatus(admin, { userId: request.userId });
  const refused = pendingDecision(target?.status ?? null);
  if (refused) return fail(refused);

  if (request.action === "resend") {
    // Inviting an email whose invitation isn't accepted yet sends it again.
    const { error } = await admin.auth.admin.inviteUserByEmail(target!.email, {
      redirectTo,
    });
    if (error) {
      console.error(`manage-admins: resend failed (${error.status} ${error.code})`);
      return fail(authErrorCode(error));
    }
    return json({ result: "resent" });
  }

  // Cancel: the account was never used, so it goes completely (its
  // admin_users and profile rows go with it).
  const { error } = await admin.auth.admin.deleteUser(target!.user_id);
  if (error) {
    console.error(`manage-admins: cancel failed (${error.status} ${error.code})`);
    return fail("failed");
  }
  return json({ result: "cancelled" });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (request.method !== "POST") return json({ error: "invalid_request" }, 405);

  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return fail("unauthorized");

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    console.error("manage-admins: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing");
    return fail("failed");
  }
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    // Checks the token with Supabase Auth: who is asking.
    const { data: caller, error: callerError } = await admin.auth.getUser(token);
    if (callerError || !caller.user) return fail("unauthorized");

    const callerAccount = await accountStatus(admin, { userId: caller.user.id });
    if (callerAccount?.status !== "admin") return fail("not_admin");

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return fail("invalid_request");
    }
    const parsed = parseRequest(body);
    if ("error" in parsed) return fail(parsed.error);

    const siteUrl = (Deno.env.get("ADMIN_SITE_URL") ?? DEFAULT_ADMIN_SITE_URL).replace(/\/+$/, "");
    const redirectTo = inviteRedirect(parsed.redirectTo, `${siteUrl}/accept-invite`);
    return await handle(admin, parsed, redirectTo);
  } catch (error) {
    console.error(`manage-admins: ${error instanceof Error ? error.message : "unexpected error"}`);
    return fail("failed");
  }
});
