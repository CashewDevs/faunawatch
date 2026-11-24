# FaunaWatch email templates

Supabase Auth's emails, in the FaunaWatch design: blue header with the yellow
fox and "FaunaWatch" logo, a white card, and a yellow button with navy text.
The suspension emails (`supabase/functions/send-suspension-email/logic.ts`)
use the same design.

| File | Dashboard template | Subject |
|---|---|---|
| `recovery.html` | Reset password | Reset your FaunaWatch password |
| `invite.html` | Invite user | You're invited to FaunaWatch Admin |
| `confirmation.html` | Confirm sign up | Confirm your FaunaWatch email |
| `email_change.html` | Change email address | Confirm your new FaunaWatch email |

Magic link and Reauthentication aren't used by the app or the admin site, so
they keep Supabase's default text.

## Where they are used

- **Local:** `supabase/config.toml` points at these files. Restart the stack
  (`supabase stop`, `supabase start`) after changing one, and read the emails
  in Mailpit (http://127.0.0.1:54324).
- **Hosted:** hosted sends through Brevo (Authentication > Emails > SMTP
  Settings), which allows custom templates. Dashboard > Authentication >
  Emails > Templates > pick the template, paste the subject and the whole
  file, and save. Do this again whenever a file changes.

## Rules

- **One layout.** The files share the same layout; there is no "include", so
  a design change must be made in every file (and in `logic.ts`).
- **Logo.** Loaded from
  `https://faunawatch-admin.vercel.app/email/faunawatch-logo.png` (the
  `faunawatch-admin` repo's `public/email/`). Email apps need a public https
  address. If the admin site's address changes, update every file.
- **Inline styles and tables only.** Many email apps ignore `<style>` blocks,
  flexbox and web fonts (DM Sans shows only where it is installed; Arial
  otherwise).
- **Reset link.** `recovery.html` sends the app
  (`com.faunawatch.app://login-callback/`) to `{{ .ConfirmationURL }}`, which
  goes through Supabase and then opens the app. Any other site (the admin
  site's `/reset-password`) gets `{{ .RedirectTo }}#token_hash=...` directly,
  which works in any browser. An app link can't be put in the email itself:
  email apps drop links that aren't `https://`.
- **Invite link.** `invite.html` links to `{{ .RedirectTo }}#token_hash=...`:
  the admin site's `/accept-invite` page, which the Admins page (Edge
  Function `manage-admins`) sets as the redirect. Invite admins from there,
  not from the Dashboard's "Invite user", whose redirect is the Site URL.
- **Expiry.** The text says links expire in 1 hour: Supabase's "Email OTP
  Expiration" setting (3600 seconds by default). Update the text if that
  setting changes.
