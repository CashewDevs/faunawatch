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

### Browser rendering

The web bootstrap uses CanvasKit software rendering for Flutter's interface to
avoid browser GPU stencil-buffer and shader failures. Mapbox still uses its own
WebGL canvas for the map, so browser WebGL support remains necessary. This can
use more CPU for the web interface; Android and iOS rendering are unaffected.

After changing the bootstrap, stop the running Flutter session, start it again,
and refresh the browser page. A Dart hot restart does not reload the bootstrap
or replace an already failed browser graphics context.

Reference: [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization#canvaskit-options).

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

## Community map and FaunaGuard

The map shows approved reports at the approximate coordinates returned by
`community_reports()`. Refresh reloads reports; pins open anonymous previews,
with a link to the full post in For You.

FaunaGuard is off by default. Tap the shield beside Refresh to open its animated
flip-card explanation, then choose **Turn on FaunaGuard**. After location and
notification access are granted, a blue marker and the map camera follow the
device. All approved report categories are monitored: **Getting closer** at
1 km and **Nearby** at 500 m. Distances use the public approximate pins (about
1 km precision), so they are estimates, not an animal's current position.
Each report alerts once per band per enabled session. Simultaneous crossings
are grouped into one notification, featuring the closest report.

Tracking continues across tabs and while the app is backgrounded or the phone
is locked. Android uses geolocator's location foreground service, started only
from the visible app, with an ongoing notification and wake lock. iOS enables
the `location` background mode with its visible location indicator. The existing
geolocator Android/Apple packages provide GPS; `flutter_local_notifications`
22.x provides immediate system notifications. Android enables Java desugaring
and retains the notification icon for release builds. No backend changes,
FCM, scheduled alarms, or background-location permission on Android are needed
for this user-started foreground-service session.

Coordinates and notification history are not stored or uploaded by FaunaGuard.
It loads approved reports when enabled and refreshes them every minute while
active. Failed refreshes or GPS/notification errors turn it off with a retry
message. The shield stops tracking and clears the marker and proximity
notification. Signing out or switching accounts also stops it. It does not
restart after force-close, process termination or reboot; device battery
management can interrupt background operation. Web preview shows the explanation
but background tracking is supported only on Android/iOS. These local alerts do
not create rows in the in-app Notifications inbox or `warning_zones`.

Device checks (Android and iOS): enable/deny each permission, enable GPS, walk or
simulate movement across both thresholds, verify the moving marker and no
duplicate alerts, lock the phone and verify system alerts, return to the app,
turn off, sign out, and force-close/reopen to confirm tracking stays off.
Check iOS foreground notification banners and Android release notification
icons on a real device before release. iOS builds require macOS/Xcode.

References: [geolocator background configuration](https://pub.dev/packages/geolocator),
[local notification setup](https://pub.dev/packages/flutter_local_notifications/versions/22.3.3),
[Android while-in-use location](https://developer.android.com/codelabs/while-in-use-location),
and [iOS background location authorization](https://developer.apple.com/documentation/corelocation/requestwheninuseauthorization()).
