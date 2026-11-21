# send-push

Supabase Edge Function (Deno) that sends a push notification through Firebase
Cloud Messaging (HTTP v1) when a row is created or refreshed in
`public.notifications`.

## How it is triggered

A Database Webhook on `public.notifications` for **INSERT** and **UPDATE**
calls this function with `{ type, table, record, old_record }`.

- INSERT: always pushes.
- UPDATE: pushes only for a grouped refresh (chat/like notifications that update
  an unread row): `created_at` changed and `read_at` is null. Mark read, mark
  unread and any other update never push.
- Every notification type is pushed (including `nearby_alert`, which nothing
  generates yet). Unknown types are pushed too; the app just opens the app.
- Suspended recipients (`public.is_suspended`) get no push.
- Notifications that group (same chat thread, same report and type) share a
  tag / collapse id, so the new one replaces the old one on the device.

## Setup

1. Apply `supabase/migrations/20261120100000_create_device_tokens.sql`.
2. Secrets (never commit them):

   ```bash
   supabase secrets set WEBHOOK_SECRET=<random> \
     FIREBASE_SERVICE_ACCOUNT="$(cat keys/service-account.json)"
   ```

   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.
3. Deploy: `supabase functions deploy send-push --no-verify-jwt`
   (`verify_jwt = false` is also in `supabase/config.toml`).
4. Dashboard > Database > Webhooks > create: table `notifications`, events
   Insert + Update, HTTP Request `POST`
   `https://<project-ref>.supabase.co/functions/v1/send-push`, header
   `x-webhook-secret: <the same WEBHOOK_SECRET>`.

## Behavior

- Requests without the correct `x-webhook-secret` get 401.
- Tokens come from `public.device_tokens` (service role). Tokens that FCM
  reports as `UNREGISTERED`, or `INVALID_ARGUMENT` about the token, are deleted.
- The access token is obtained by signing an RS256 JWT with the service account
  key using Web Crypto (no third-party library) and cached until it expires.
- Push `data`: `notification_id`, `type`, `report_id`, `thread_id` (strings; the
  app uses them to open the right screen). Android uses high priority and the
  `faunawatch_default` channel (high importance, created by the app); iOS uses the default sound.
- Tokens, keys and message contents are never logged.

## Tests

`logic.ts` holds the pure filtering and payload code; `logic_test.ts` tests it.
Run `deno test supabase/functions/send-push/logic_test.ts` (needs Deno).
