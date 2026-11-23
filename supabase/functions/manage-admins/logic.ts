// Pure rules for manage-admins: no network, no environment access, so they
// are easy to unit test (see logic_test.ts).

export type Action = "invite" | "resend" | "cancel";

/** What public.admin_account_status() says about an account. */
export type AccountStatus = "admin" | "invited" | "former_admin" | "account";

export type InviteRequest = { action: "invite"; email: string; redirectTo?: string };
export type PendingRequest = {
  action: "resend" | "cancel";
  userId: string;
  redirectTo?: string;
};
export type ManageRequest = InviteRequest | PendingRequest;

/**
 * Error codes the admin site turns into messages. Nothing else (no Supabase
 * error text) is ever returned.
 */
export type ErrorCode =
  | "unauthorized" // not signed in
  | "not_admin" // signed in, but not an active admin
  | "invalid_request"
  | "invalid_email"
  | "already_admin"
  | "already_invited" // use Resend instead
  | "has_account" // an app account; admin accounts are separate
  | "not_invited" // resend/cancel of someone without a pending invitation
  | "rate_limited"
  | "failed";

export const errorStatus: Record<ErrorCode, number> = {
  unauthorized: 401,
  not_admin: 403,
  invalid_request: 400,
  invalid_email: 400,
  already_admin: 409,
  already_invited: 409,
  has_account: 409,
  not_invited: 409,
  rate_limited: 429,
  failed: 500,
};

const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Trimmed and lower-cased, or null when it isn't an email address. */
export function normaliseEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  if (email.length > 254 || !EMAIL_PATTERN.test(email)) return null;
  return email;
}

/** The request body, or the reason it can't be used. */
export function parseRequest(body: unknown): ManageRequest | { error: ErrorCode } {
  if (typeof body !== "object" || body === null) return { error: "invalid_request" };
  const { action, email, userId, redirectTo } = body as Record<string, unknown>;
  const redirect = typeof redirectTo === "string" ? redirectTo : undefined;

  if (action === "invite") {
    const normalised = normaliseEmail(email);
    if (!normalised) return { error: "invalid_email" };
    return { action, email: normalised, redirectTo: redirect };
  }
  if (action === "resend" || action === "cancel") {
    if (typeof userId !== "string" || !UUID_PATTERN.test(userId)) {
      return { error: "invalid_request" };
    }
    return { action, userId, redirectTo: redirect };
  }
  return { error: "invalid_request" };
}

/**
 * What inviting an email does, given its account's status (null: no account
 * uses it yet).
 */
export function inviteDecision(
  status: AccountStatus | null,
): { step: "invite" } | { step: "restore" } | { error: ErrorCode } {
  switch (status) {
    case null:
      return { step: "invite" };
    case "former_admin":
      // Removed earlier: their account and password still work.
      return { step: "restore" };
    case "admin":
      return { error: "already_admin" };
    case "invited":
      return { error: "already_invited" };
    case "account":
      return { error: "has_account" };
  }
}

/** Resend and cancel only apply to an invitation not yet accepted. */
export function pendingDecision(status: AccountStatus | null): ErrorCode | null {
  return status === "invited" ? null : "not_invited";
}

/**
 * Where the invitation link should lead: the admin site's accept-invite page
 * the request came from, if it looks like one (Supabase also checks it
 * against its Redirect URLs), else [fallback].
 */
export function inviteRedirect(requested: string | undefined, fallback: string): string {
  if (!requested) return fallback;
  let url: URL;
  try {
    url = new URL(requested);
  } catch {
    return fallback;
  }
  const local = url.hostname === "localhost" || url.hostname === "127.0.0.1";
  const secure = url.protocol === "https:" || (url.protocol === "http:" && local);
  if (!secure || url.pathname !== "/accept-invite" || url.search || url.hash) {
    return fallback;
  }
  return url.toString();
}

/** An Auth admin API error as one of our codes. */
export function authErrorCode(error: { status?: number; code?: string } | null): ErrorCode {
  if (error?.status === 429) return "rate_limited";
  if (error?.code === "email_exists" || error?.code === "user_already_exists") {
    return "has_account";
  }
  return "failed";
}
