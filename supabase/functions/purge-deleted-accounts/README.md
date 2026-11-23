# purge-deleted-accounts

Supabase Edge Function (Deno) that permanently deletes the accounts whose 7
days are up, then emails each person "Your FaunaWatch account has been
deleted" through Brevo.

## How it is triggered

A Supabase Cron job calls it every hour (`POST`, header
`x-webhook-secret: <WEBHOOK_SECRET>`). Requests without the right secret get
401. Each run handles up to 20 due accounts, oldest first
(`public.due_account_deletions()`; admins are never included). For each one:

1. reads the email address and name (they are gone after step 3);
2. removes its files through the Storage API
   (`public.account_storage_objects()`): `avatars/{user_id}/…`, the user's
   report photos (`report-images/{report_id}/…` and the older
   `{user_id}/…`), and `chat-images` in the user's own folder or in their
   chats (those chats are deleted too);
3. deletes the sign-in account (`auth.admin.deleteUser`); "on delete
   cascade" removes the profile, reports, comments, likes, chats,
   notifications, device tokens and the `account_deletions` row;
4. sends the email.

If step 1, 2 or 3 fails, the account is left for the next hour. Without the
Brevo settings accounts are still deleted on time; only the email is
skipped. The response and log hold counts only, e.g.
`{"due":1,"deleted":1,"emailFailed":0,"failed":0}`.

## Setup

Needs `20261124090000_add_account_deletion.sql` and
`20261124120000_add_account_purge_helpers.sql` applied. Same secrets as
`send-account-deletion-email`; nothing new to set.

1. Deploy: `supabase functions deploy purge-deleted-accounts --no-verify-jwt`.
2. Dashboard > Integrations > Cron: enable it, then create a job that runs
   every hour (`0 * * * *`), type Supabase Edge Function
   (`purge-deleted-accounts`, method `POST`), header
   `x-webhook-secret: <the WEBHOOK_SECRET value>`, body `{}`.

## Code and tests

`logic.ts` holds the pure parts (file batches per bucket, the run summary);
`index.ts` does the work and imports the email text and Brevo sending from
`../send-account-deletion-email/`.

`deno test supabase/functions/purge-deleted-accounts/logic_test.ts` (or the
Docker command in `../send-account-deletion-email/README.md`).
