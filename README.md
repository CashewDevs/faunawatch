# faunawatch
A Flutter-based mobile application for FaunaWatch, an AI-assisted platform for wildlife reporting, species identification, and environmental monitoring.

## Configuration

The community map uses Mapbox. Provide its public access token at build time;
do not commit it to source control:

```bash
flutter run --dart-define=MAPBOX_PUBLIC_TOKEN=<your-public-token>
```

The existing VS Code launch configuration reads the same value from the
ignored `dart_defines.json` file.

## Google authentication (Android and iOS)

Login and registration both use Supabase Google OAuth in the external browser.
The existing `supabase_flutter` dependency handles PKCE and the app callback;
no Google SDK or client secret is bundled in the mobile app.

Before testing:

1. In Google Cloud, configure the OAuth consent screen and create a **Web
   application** OAuth client. Register the callback URL shown in Supabase's
   Google provider settings as an authorized redirect URI (normally
   `https://<project-ref>.supabase.co/auth/v1/callback`). If the consent screen
   is in testing mode, add your test users.
2. In Supabase Authentication → Sign In / Providers → Google, enable Google
   and enter that web client's ID and secret. Keep the secret in Supabase's
   provider configuration only.
3. In Supabase Authentication → URL Configuration → Redirect URLs, add exactly
   `com.faunawatch.app://login-callback/`. This matches the Android intent
   filter, iOS URL scheme, and `SupabaseGoogleAuthService.redirectUrl`.
4. Run with the existing `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
   `MAPBOX_PUBLIC_TOKEN` build defines. No extra Google build defines are needed.

The existing profile-creation trigger also handles Google accounts. A confirmed
session with no profile display name opens profile setup; an existing named
profile opens the app. Launching the browser does not count as signing in.
Returning without finishing leaves a Cancel action available, and a missing
callback times out after three minutes. Cancel stops waiting in the app; it
does not revoke consent already granted in the browser. Session restoration
uses the same profile check at startup and offers Retry if it fails.

Manual device checks: sign in from both auth screens, choose a new Google
account and finish profile setup, sign out and sign back in, close and reopen
the app, cancel in the browser, deny consent, and retry while offline. Verify
the return link on both Android and iOS, including when the app was terminated.
No hosted configuration is changed by this repository update.

Reference: [Supabase OAuth for Flutter](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
and [mobile deep linking](https://supabase.com/docs/guides/auth/native-mobile-deep-linking).

## Map demo

The map starts in Cebu City with a synthetic incident pin, colored warning
zones, and a blue simulated-position marker. Dismiss the preview card with X
to select Approaching, Near, or Danger Zone. The info button reopens the
preview; the demo controls can also be collapsed and reopened.

The 900 m / 500 m / 180 m radii are demo presets only, not approved proximity
thresholds. This demo does not read GPS, query reports, send notifications,
or write sample data to Supabase. Replace it when live reporting is connected.
