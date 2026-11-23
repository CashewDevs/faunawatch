# send-account-deletion-email

Supabase Edge Function (Deno) that emails a user through Brevo when they ask
to delete their account, and when they keep it. The third email ("your
account has been deleted") is sent by
[`purge-deleted-accounts`](../purge-deleted-accounts/README.md).

## How it is triggered

A Database Webhook on `public.account_deletions` for **INSERT** and
**UPDATE** calls this function with `{ type, table, record, old_record }`:

- INSERT of a waiting deletion, or an UPDATE that clears `cancelled_at`
  (asked again after keeping the account): "Your FaunaWatch account will be
  deleted", with the date (in `EMAIL_TIME_ZONE`), how to keep it, and what is
  deleted.
- UPDATE that sets `cancelled_at` ("Keep my account" in the app): "Your
  FaunaWatch account is restored".
- DELETE (the account was finally deleted) and anything else: nothing.

Asking again while already waiting changes no row, so it sends nothing.

## Setup

Needs `20261124090000_add_account_deletion.sql` applied. It uses the same
secrets as `send-suspension-email` (`WEBHOOK_SECRET`, `BREVO_API_KEY`,
`EMAIL_SENDER_ADDRESS`, optional `EMAIL_SENDER_NAME`, `EMAIL_REPLY_TO`,
`EMAIL_TIME_ZONE`); see its README. Nothing new to set.

1. Deploy: `supabase functions deploy send-account-deletion-email --no-verify-jwt`
   (`verify_jwt = false` is also in `supabase/config.toml`).
2. Dashboard > Database > Webhooks > Create a new hook: table
   `account_deletions`, events Insert + Update, type Supabase Edge Functions
   (`send-account-deletion-email`, method `POST`), header
   `x-webhook-secret: <the WEBHOOK_SECRET value>`.

## Code

- `logic.ts`: which email an event needs and the three emails' text. The
  layout is the shared FaunaWatch design from
  `../send-suspension-email/logic.ts` (`render`). Brevo requests are tagged
  `account-deletion`.
- `send.ts`: email settings, Brevo sending and the webhook secret check,
  shared with `purge-deleted-accounts`.
- Nothing secret or personal (keys, ids, addresses, names) is logged.

## Tests

`deno test supabase/functions/send-account-deletion-email/logic_test.ts`
(or with Docker: `docker run --rm -v "<repo>/supabase/functions:/fn" -w /fn
denoland/deno:2.1.4 test send-account-deletion-email/logic_test.ts`).
