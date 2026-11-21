// send-push: pushes a public.notifications row to the recipient's devices.
//
// Triggered by a Supabase Database Webhook on public.notifications (INSERT and
// UPDATE). See README.md in this folder for setup.
//
// Environment:
//   WEBHOOK_SECRET            shared secret the webhook sends in x-webhook-secret
//   FIREBASE_SERVICE_ACCOUNT  the Firebase service account key (JSON)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  provided by Supabase
//
// Nothing secret or user-specific (tokens, keys, titles, bodies) is logged.

import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import {
  buildFcmMessage,
  isInvalidTokenResponse,
  shouldSend,
  type WebhookPayload,
} from "./logic.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const TOKEN_URL = "https://oauth2.googleapis.com/token";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

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

function base64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const der = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) der[i] = binary.charCodeAt(i);
  return der.buffer;
}

// OAuth2 access token, reused until shortly before it expires.
let cachedToken: { value: string; expiresAt: number } | null = null;

/** Signs a JWT (RS256, Web Crypto) with the service account key and exchanges
 * it for an OAuth2 access token. */
async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.value;

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: FCM_SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const assertion = `${header}.${claims}.${base64url(signature)}`;

  const response = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`token exchange failed (${response.status})`);
  const result = await response.json();
  cachedToken = {
    value: result.access_token as string,
    expiresAt: now + (Number(result.expires_in) || 3600),
  };
  return cachedToken.value;
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
  if (!shouldSend(payload)) return json({ skipped: "not a push event" });
  const record = payload.record!;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const accountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!supabaseUrl || !serviceKey || !accountJson) {
    console.error("send-push: missing configuration");
    return json({ error: "not configured" }, 500);
  }

  let account: ServiceAccount;
  try {
    account = JSON.parse(accountJson);
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("incomplete");
    }
  } catch {
    console.error("send-push: FIREBASE_SERVICE_ACCOUNT is not a valid key");
    return json({ error: "not configured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  // Suspended users get no pushes, like chat notifications.
  const suspended = await supabase.rpc("is_suspended", { p_uid: record.user_id });
  if (suspended.error) {
    console.error("send-push: suspension check failed");
    return json({ error: "lookup failed" }, 500);
  }
  if (suspended.data === true) return json({ skipped: "suspended" });

  const tokens = await supabase
    .from("device_tokens")
    .select("token")
    .eq("user_id", record.user_id);
  if (tokens.error) {
    console.error("send-push: token lookup failed");
    return json({ error: "lookup failed" }, 500);
  }
  const deviceTokens = (tokens.data ?? []).map((row) => row.token as string);
  if (deviceTokens.length === 0) return json({ sent: 0, removed: 0 });

  let accessToken: string;
  try {
    accessToken = await getAccessToken(account);
  } catch {
    console.error("send-push: could not get a Firebase access token");
    return json({ error: "auth failed" }, 502);
  }

  const url =
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`;
  let sent = 0;
  let failed = 0;
  const invalid: string[] = [];

  await Promise.all(deviceTokens.map(async (token) => {
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(buildFcmMessage(record, token)),
      });
      if (response.ok) {
        sent++;
        await response.body?.cancel();
        return;
      }
      const body = await response.json().catch(() => null);
      if (isInvalidTokenResponse(response.status, body)) invalid.push(token);
      else failed++;
    } catch {
      failed++;
    }
  }));

  if (invalid.length > 0) {
    const removal = await supabase.from("device_tokens").delete().in(
      "token",
      invalid,
    );
    if (removal.error) console.error("send-push: could not remove dead tokens");
  }

  return json({ sent, failed, removed: invalid.length });
});
