# manage-admins

Supabase Edge Function (Deno) that lets an admin, from the admin site:

- **invite** another admin by email (Supabase Auth's "Invite user" email,
  sent through Brevo in the FaunaWatch design, `supabase/templates/invite.html`);
- **resend** an invitation that hasn't been accepted (inviting the same email
  again sends a new link; the old one stops working);
- **cancel** an invitation (the unused account is deleted).

Listing admins and removing an active admin are database functions, called
directly by the admin site: `admin_list_admins()` and
`admin_remove_admin(p_user_id)` (migration
`20261124150000_add_admin_management.sql`).

## Rules

- The caller must be signed in and an **active** admin (accepted the
  invitation). The function checks the session token with Supabase Auth
  itself, so it is deployed with `--no-verify-jwt` (`config.toml`).
- An email that already has an app account is refused (`has_account`):
  admin accounts are separate from app accounts (decided 2026-11-24).
- An email that is already an admin (`already_admin`) or already invited
  (`already_invited`, use resend) is refused.
- A **removed** admin's account is kept (their name stays on past decisions)
  and listed in `public.former_admins`; inviting the same email again gives
  admin access back without an email (`restored`). They log in with their old
  password, or use Forgot password.
- Nobody removes themselves, and the last active admin can't be removed
  (`admin_remove_admin`).

## Request and answer

`POST /functions/v1/manage-admins` with the admin's session
(`supabase.functions.invoke("manage-admins", { body })`):

| `body` | Answer |
|---|---|
| `{ "action": "invite", "email": "...", "redirectTo": "<site>/accept-invite" }` | `{ "result": "invited" }` or `{ "result": "restored" }` |
| `{ "action": "resend", "userId": "...", "redirectTo": "..." }` | `{ "result": "resent" }` |
| `{ "action": "cancel", "userId": "..." }` | `{ "result": "cancelled" }` |

Errors are `{ "error": "<code>" }`: `unauthorized` (401), `not_admin` (403),
`invalid_request` / `invalid_email` (400), `already_admin`,
`already_invited`, `has_account`, `not_invited` (409), `rate_limited` (429),
`failed` (500). Supabase's own error text is never returned or logged, nor
are email addresses or tokens.

`redirectTo` is used only when it is an `https://` (or `http://localhost`)
address ending in `/accept-invite`; otherwise the link leads to
`<ADMIN_SITE_URL>/accept-invite`. Supabase also requires it to be in
Authentication > URL Configuration > Redirect URLs.

## Setup (hosted)

1. Run the migration `20261124150000_add_admin_management.sql` (SQL Editor).
2. Deploy:
   `supabase functions deploy manage-admins --no-verify-jwt --project-ref cvqcejsnwffotqqlekil`
   (always name the project: the CLI may offer another one).
3. Optional secret `ADMIN_SITE_URL` (default
   `https://faunawatch-admin.vercel.app`).
4. Redirect URLs: add `https://faunawatch-admin.vercel.app/accept-invite**`.
5. Invites share Supabase's email limit (Authentication > Rate Limits) and
   Brevo's 300 emails a day with every other FaunaWatch email.

## Tests

`logic.ts` holds the pure rules; `logic_test.ts` tests them. Run
`deno test supabase/functions/manage-admins/logic_test.ts` (needs Deno, or
Docker: `docker run --rm -v "<repo>/supabase/functions:/fn" -w /fn
denoland/deno:2.1.4 test manage-admins/logic_test.ts`).
