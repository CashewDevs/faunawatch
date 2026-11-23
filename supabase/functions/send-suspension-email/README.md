# send-suspension-email

Supabase Edge Function (Deno) that emails a user through Brevo when they are
suspended, and when an admin lifts their suspension early.

## How it is triggered

A Database Webhook on `public.user_sanctions` for **INSERT** and **UPDATE**
calls this function with `{ type, table, record, old_record }`. It uses the
same rules as the in-app notification (`notify_user_sanction()`):

- INSERT of a suspension in force now: "Your FaunaWatch account has been
  suspended" with the reason (category), the admin's message, how long, the
  end date, and what the user can't do (restricted or locked).
- UPDATE that lifts a suspension still in force (Reactivate on the admin
  site): "Your FaunaWatch account is active again".
- A suspension that simply runs out sends nothing (the app unlocks by itself).
- The admin who made the suspension is never named.

## Setup

1. Apply `20261123120000_add_account_notification_types.sql` and
   `20261123120100_add_suspension_levels.sql` (if not done already).
2. Brevo (free plan: 300 emails a day):
   1. Create an account at https://www.brevo.com.
   2. **Senders, Domains & Dedicated IPs > Senders > Add a sender**: the
      address emails come from (e.g. a Gmail address the team reads). Brevo
      sends it a code; confirm it.
   3. **SMTP & API > API keys > Generate a new API key**. Copy it once; it is
      not shown again.

   Without a domain of your own, some emails may land in spam. Adding a domain
   later (Senders, Domains & Dedicated IPs > Domains) fixes that; nothing here
   changes.
3. Secrets (never commit them). Secrets are shared by all functions, so this
   function reuses send-push's `WEBHOOK_SECRET` (already set; its value is in
   the git-ignored `keys/webhook-secret.txt`). Do not set it again, or
   send-push's webhook stops working. Only add:

   ```bash
   supabase secrets set \
     BREVO_API_KEY=<the Brevo API key> \
     EMAIL_SENDER_ADDRESS=<the verified sender address> \
     EMAIL_TIME_ZONE=Asia/Manila
   ```

   Optional: `EMAIL_SENDER_NAME` (default `FaunaWatch`) and `EMAIL_REPLY_TO`
   (when set, replies go there and the email says "If you think this is a
   mistake, reply to this email"). `EMAIL_TIME_ZONE` is any IANA zone; without
   it dates are in UTC. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are
   provided automatically.
4. Deploy: `supabase functions deploy send-suspension-email --no-verify-jwt`
   (`verify_jwt = false` is also in `supabase/config.toml`).
5. Dashboard > Database > Webhooks > Create a new hook: table
   `user_sanctions`, events Insert + Update, type Supabase Edge Functions (or
   HTTP Request `POST`
   `https://<project-ref>.supabase.co/functions/v1/send-suspension-email`),
   header `x-webhook-secret: <the WEBHOOK_SECRET value>` (the same header as
   the send-push webhook).

## Behavior

- Requests without the correct `x-webhook-secret` get 401.
- The address comes from `auth.users` and the greeting name from `profiles`
  (full name, then username), read with the service role. A user without an
  email address is skipped.
- The admin's message is escaped in the HTML version.
- If Brevo refuses, the function answers 502 with Brevo's status and error
  code (e.g. `unauthorized` = wrong API key, `invalid_parameter` = sender not
  verified), visible in Dashboard > Edge Functions > send-suspension-email >
  Logs and in the webhook's responses (`net._http_response`).
- Keys, email addresses, names and messages are never logged.
- `BREVO_API_URL` replaces Brevo's address; it is only for local testing
  against a pretend server.

## Tests

`logic.ts` holds the pure rules and email text; `logic_test.ts` tests it.
Run `deno test supabase/functions/send-suspension-email/logic_test.ts`
(needs Deno, or Docker: `docker run --rm -v "<repo>/supabase/functions:/fn"
-w /fn denoland/deno:2.1.4 test send-suspension-email/logic_test.ts`).
