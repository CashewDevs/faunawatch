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

## Release a new Android version

Testers and users install FaunaWatch from this repository's GitHub Releases,
outside the Play Store. The app finds new releases by itself: it checks GitHub
when it opens (at most every 6 hours) and shows a large "New version
available" card at the top of the Feed, with the first line of the release
notes. "Not now" hides it only until the app is opened again. Settings › Check
for updates checks at any time. Update downloads the new version and opens
Android's installer; data and sign-in are kept. iPhones cannot install apps
this way (use TestFlight).

### When to release

**Many changes, one release.** Don't release after every change. While coding,
test on your own phone straight from your computer
(`flutter run --release --dart-define-from-file=dart_defines.json`, or Run in
VS Code); no GitHub step is needed. Publish a release only when a batch of
merged changes is ready for testers (for example weekly, or when a set of
features is done). Each release then includes everything merged into `main`
since the previous one, and testers see one update instead of many.

### Before the first release

- **One builder.** Android only installs an update when it is signed with the
  same key as the app already on the phone. Release builds are currently signed
  with the builder's own computer key, `%USERPROFILE%\.android\debug.keystore`
  (Windows). Always build releases on the same computer, and keep a private
  backup of that file (never commit it). If it is lost, everyone must uninstall
  and reinstall once.
- **The public link** always downloads the newest version; share it or turn it
  into a QR code:
  <https://github.com/CashewDevs/faunawatch/releases/latest/download/faunawatch.apk>
  First-time installs must allow "Install unknown apps" for their browser, and
  Play Protect may warn about an unknown developer ("Install anyway").

### Every release

1. **Raise the build number** (the number after `+`) in `pubspec.yaml`, e.g.
   `version: 1.0.0+4` → `version: 1.0.0+5`. It must be higher than the last
   release, or phones refuse the update. Change the part before `+` too when
   it is a bigger release (`1.1.0+6`).
2. **Build** on the builder's computer, from the code being released:
   ```bash
   flutter build apk --release --dart-define-from-file=dart_defines.json
   ```
3. **Rename** `build/app/outputs/flutter-apk/app-release.apk` to exactly
   `faunawatch.apk`. The app and the public link look for that name.
4. **Publish** at <https://github.com/CashewDevs/faunawatch/releases/new>:
   - **Tag:** `v` + the full version from `pubspec.yaml`, e.g. `v1.0.0+5`
     ("Create new tag on publish"). The app reads the version from the tag.
   - **Target:** the branch with this code (usually `main`).
   - **Title:** e.g. `FaunaWatch 1.0.0 (5)`.
   - **Notes:** short, plain sentences. They appear in the app under
     "What's new".
   - **Attach** `faunawatch.apk` in the "Attach binaries" box (not the
     description box) and wait for the upload to finish.
   - **Release label:** Latest. The app skips pre-releases and drafts.
5. **Commit** the `pubspec.yaml` version change so the next release starts
   from it.

To check what the app will see:
<https://api.github.com/repos/CashewDevs/faunawatch/releases/latest> must show
your tag and a `faunawatch.apk` asset.

### Testing an update

A phone only sees an update when the release's build number is higher than the
installed one. To test, install a build with a lower number (e.g.
`flutter build apk --release --build-number=4 ...` then `adb install -r`), then
publish the higher one. Android cannot put a lower number back over a higher
one without uninstalling (which signs the user out and erases saved AI keys).
To see the one-time permission step again, turn off Settings › Apps ›
FaunaWatch › Install unknown apps.

The Feed card uses the app's last answer from GitHub for up to 6 hours, so a
release published after the app was opened may not show at once. To see it
right away, tap Settings › Check for updates (it refreshes the saved answer),
then close and reopen the app.

> **Google Play:** Play does not allow apps that install their own updates.
> Before any Play Store build, remove `REQUEST_INSTALL_PACKAGES` from
> `AndroidManifest.xml` and the update banner and button.

## Enable push notifications

Push notifications (Firebase Cloud Messaging) are built in but stay **off**
until you add your Firebase config. Without the config files the app builds and
runs exactly as before; push is silently disabled. Nothing below is applied by
the repository: you run each step yourself.

1. **Create a Firebase project** at <https://console.firebase.google.com>.
2. **Android app.** Add an Android app whose package name is the real
   `applicationId` in `android/app/build.gradle.kts`, currently
   `com.example.faunawatch` (not `com.faunawatch.app`, which is only the OAuth
   URL scheme). If you change the application ID to a final one first, use that.
   Download `google-services.json` and put it in `android/app/` (git-ignored,
   never committed; share it privately with teammates). The Android build applies
   the `com.google.gms.google-services` Gradle plugin automatically when it
   exists; without it the app builds with push disabled.
3. **iOS app.** Add an iOS app with the bundle ID from Xcode (currently
   `com.example.faunawatch`), download `GoogleService-Info.plist`, and add it to
   `ios/Runner` **through Xcode** (the file is git-ignored in `ios/Runner`, never
   committed; share it privately with teammates; drag it into the Runner group, tick "Copy
   items if needed" and the Runner target). On a Mac, open `ios/Runner.xcworkspace`
   and under Signing & Capabilities check that "Push Notifications" and
   "Background Modes > Remote notifications" are present (they are already
   configured through `Runner.entitlements` and `Info.plist`; enable Push
   Notifications for the App ID in the Apple Developer portal if Xcode asks).
4. **APNs key.** In the Apple Developer portal create an APNs Authentication
   Key (.p8), then in Firebase > Project settings > Cloud Messaging > Apple app
   configuration, upload it with your Key ID and Team ID. Push cannot be tested
   in the iOS simulator; use a real device.
5. **Service account key.** In Firebase > Project settings > Service accounts,
   generate a new private key (JSON). Keep it outside git, e.g. in `keys/`
   (git-ignored; the build never uses it). Never commit it.
6. **Set the Edge Function secrets and deploy** (Supabase CLI; the repo's
   untracked `tools/supabase/supabase.exe` also works):

   ```bash
   supabase secrets set WEBHOOK_SECRET=<a-long-random-string>      FIREBASE_SERVICE_ACCOUNT="$(cat keys/service-account.json)"
   supabase functions deploy send-push --no-verify-jwt
   ```

   After changing the function (for example the Android banner channel below)
   it must be **redeployed**:
   `.\tools\supabase\supabase.exe functions deploy send-push --no-verify-jwt --use-api`.

   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase.
   `--no-verify-jwt` (also set in `supabase/config.toml`) is needed because the
   webhook authenticates with the shared secret, not a user JWT.
7. **Apply the migration** `supabase/migrations/20261120100000_create_device_tokens.sql`
   in the Supabase SQL editor, after the notification migrations
   (`20261112090000`, `20261120090000`, `20261120090100`).
8. **Create the Database Webhook.** Supabase Dashboard > Database > Webhooks >
   Create a new hook: table `public.notifications`, events **Insert** and
   **Update** (not Delete), type "HTTP Request", method `POST`, URL
   `https://<project-ref>.supabase.co/functions/v1/send-push`, and an HTTP
   header `x-webhook-secret` with the same value as `WEBHOOK_SECRET`. The
   function sends a push for new notifications and for grouped refreshes (a new
   chat message or like on an unread notification), never for marking read.
9. **Test.** Install a build on a real device, sign in and allow notifications,
   then have another account message or like a report. The app registers its
   token on sign-in, and Settings > Push notifications turns this device's
   pushes on or off.

**Pop-up banners (Android).** The app creates a high-importance notification
channel, `faunawatch_default` ("Notifications"), at start, the manifest makes it
the default for pushes, and `send-push` addresses it, so pushes pop up on screen
like a messaging app; pushes received while the app is open are shown as a
banner too (on iOS the system shows them). If the app was installed before this
channel existed, or the channel was changed in the system settings, check
Android Settings > Apps > FaunaWatch > Notifications > "Notifications" category
> "Pop on screen" is on (importance Urgent/High), and redeploy `send-push`.

See `supabase/functions/send-push/README.md` for details. Nearby alerts are not
generated yet, so they produce no pushes.

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

## Community profiles and public galleries

Tap an author's name or avatar in For You, or the author's name on a map pin's
card, to slide up a quick profile preview: their banner, picture, name and bio,
with **Message** and **View full profile** buttons. Tapping the name or avatar
in the conversation header opens the full public profile directly. In the chat
list, tapping the name, avatar or message preview opens the conversation.
Tapping your own name or avatar in For You or on the map switches to your
existing Profile tab. Public profiles
use the existing banner, avatar, DM Sans typography and themed three-column gallery.
Only approved posts appear; the owner's pending posts and preferences stay
in their own Profile tab. Category filters, pull to refresh and older-page
loading work independently of My Gallery. Tap a tile to browse that account's
posts with likes/comments; Back restores the grid, feed or chat, including an
unsent chat draft.

Before using the public gallery, you or the backend owner must run
[`20261121233000_create_public_profile_gallery.sql`](supabase/migrations/20261121233000_create_public_profile_gallery.sql)
in the Supabase SQL editor, after `20261112100000_create_community_feed.sql`
and its prerequisites. This adds an approved-only author-filtered query and
index, without changing notification SQL or table access policies. It selects
the gallery's public fields explicitly so later feed columns do not break its
return type. If you applied an earlier copy using `select f.*`, rerun the corrected
script when updating the feed. The app does not apply this script automatically.

The migration has an isolated PostgreSQL regression test, with no hosted
connection or app dependency:

```powershell
npm install --prefix .dart_tool/public-profile-sql --no-save --no-package-lock --ignore-scripts @electric-sql/pglite
node test/features/public_profile/public_gallery_security_test.cjs
```

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
