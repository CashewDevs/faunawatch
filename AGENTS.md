# FaunaWatch — AI Agent Instructions

## Project Overview

FaunaWatch is a Flutter-based mobile application for an AI-assisted wildlife
reporting and monitoring platform.

Users report wildlife sightings and incidents using photographs and location
data. AI-assisted features analyze submitted images/reports for species
identification, severity assessment, invasive-species detection, validation,
summaries, and safety recommendations.

This repository contains the FaunaWatch mobile application.

## Tech Stack

- Flutter 3.44.1 (stable channel) / Dart 3.12.1
- State management: Riverpod
- Backend: Supabase
- MVVM architecture (Model → Service → ViewModel → View)
- Secure local key storage: `flutter_secure_storage` (Android Keystore / iOS Keychain)
- Android and iOS
- AI providers: Google Gemini, Groq, OpenRouter (user-supplied keys)
- Mapping: Mapbox Maps SDK for Flutter (`mapbox_maps_flutter`); configure its
  public token through the `MAPBOX_PUBLIC_TOKEN` build-time define. The SDK
  requires iOS 14+.
- Web preview rendering: `web/flutter_bootstrap.js` uses CPU-only CanvasKit for
  Flutter's UI to avoid browser stencil-buffer/shader failures. Mapbox retains
  its separate WebGL renderer. Web UI CPU usage can increase; Android/iOS are
  unaffected. Bootstrap changes require restarting the run and refreshing the
  browser; Dart hot restart alone is insufficient.
- FaunaLens photo capture: `camera` (live preview), `exif` (location of gallery
  photos), and `geolocator_android` + `geolocator_apple` through
  `geolocator_platform_interface` (location of captured photos). Their
  permissions are declared in `AndroidManifest.xml` and `Info.plist`. Do not
  depend on the `geolocator` package itself: its Linux plugin pulls in
  `package_info_plus`, which either fails on AGP 9 built-in Kotlin or conflicts
  with `flutter_secure_storage` 9.
- Push notifications: `firebase_core` + `firebase_messaging` (FCM; Android and
  iOS), used only through `PushMessagingService` in `lib/features/push/`.
  Firebase is initialized in `main` through `initializePushMessaging()`, which
  never throws: without `google-services.json` / `GoogleService-Info.plist` it
  returns a no-op service and the app runs as before. The Android
  `com.google.gms.google-services` Gradle plugin (declared in
  `android/settings.gradle.kts`) is applied by `android/app/build.gradle.kts`
  only when `android/app/google-services.json` exists; that file is git-ignored
  (shared privately with teammates; there is no copy in `keys/`).
  `flutter_local_notifications` (^22.3.2, compatible with this project's
  AGP 9.0.1 / SDK 36) is shared by `LocalGuardNotificationService` in
  `lib/features/fauna_guard/services/` and `LocalNotificationService` in
  `lib/features/push/services/`, the latter showing a
  heads-up banner on Android when a push arrives while the app is open (FCM
  shows nothing in the foreground). It needs core library desugaring, enabled in
  `android/app/build.gradle.kts`. `firebase_messaging` 17 deprecates `getToken` and
  `onTokenRefresh` in favour of Firebase Installation IDs; the FCM HTTP v1
  sender needs registration tokens, so the deprecated calls are used (with
  `ignore` comments) in `FirebasePushMessagingService` only.
- External links (provider key consoles and terms): `url_launcher`, already
  pulled in by `supabase_flutter`, used only through `ExternalLinkService`
  in `lib/core/services/`.

## Essential Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test
dart format .
```

Do not consider a task complete if `flutter analyze` reports errors.

New or changed business logic, ViewModel behavior, repository behavior,
service behavior, or other testable application logic should have
corresponding tests.

Purely visual or documentation-only changes do not require tests unless
existing behavior is affected.

## Code Formatting

Use the standard Dart formatter.

Before considering a code change complete, format modified Dart files with:

    dart format .

Do not manually format Dart code in a way that conflicts with the Dart
formatter.

## Platform Targets

- Android is the primary development and testing platform.
- iOS is a required supported platform.
- Code must not unnecessarily depend on Android-specific behavior.
- When adding plugins or platform capabilities, verify that the dependency
  supports both Android and iOS.
- Platform-specific implementation must be isolated from shared application
  logic.
- Do not remove or disable the `ios/` project because development currently
  occurs on Windows.

## Architecture — Non-Negotiable

Strict MVVM + separation of concerns:

1. **Models** (`lib/data/models/` or feature-local `models/`): Pure Dart
   types/domain logic only. No Flutter widget imports, no direct API/DB
   calls, no side effects.
2. **Services** (`lib/core/services/` or feature-local `services/`):
   Encapsulate external integrations only — AI provider calls, Supabase
   access, device capabilities (location, camera, storage), and
   authentication. Services must not contain UI state or widgets and
   should not contain presentation logic.
3. **ViewModels**: Classes responsible for presentation state and
   presentation-related logic. Riverpod providers/notifiers are used to
   expose and manage ViewModels and their state. ViewModels call the
   Service layer and expose a clean interface to Views. No widget/UI code
   here.
4. **Views**: Flutter widgets. Presentation and user interaction only.
   Never call a Service directly, never contain business logic.
   - **Screens / Pages**: Top-level route widgets live in
     `lib/features/<feature_name>/views/screens/` (or directly in `views/`
     if the feature contains a single screen).
   - **Widgets**: Feature-specific subcomponents live in
     `lib/features/<feature_name>/views/widgets/`.
   - **Shared Widgets**: Common widgets used across features live in
     `lib/core/widgets/`.

**Repository is optional.** Introduce a Repository sub-layer only for a
feature that genuinely needs one (e.g. local cache + remote sync). Do not
add one by default, and do not introduce one solely to satisfy the
architecture.

### Directory Structure

```text
faunawatch/
├── assets/
│   ├── animations/            # Lottie (.json / .dotlottie) or Rive (.riv)
│   ├── icons/                 # Custom SVG / vector icons
│   └── images/                # PNG, JPG, WebP raster/vector images
├── lib/
│   ├── core/
│   │   ├── constants/         # AppAssets, AppColors, AppStrings
│   │   ├── services/          # Global services (Supabase, AI, location, auth)
│   │   ├── theme/             # Light/dark ThemeData, styles
│   │   └── widgets/           # App-wide reusable UI components
│   ├── features/
│   │   └── <feature_name>/    # Feature-scoped MVVM
│   │       ├── models/        # Pure domain models
│   │       ├── services/      # Feature-specific external integrations (if any)
│   │       ├── viewmodels/    # Riverpod Notifiers / State classes
│   │       ├── views/
│   │       │   ├── screens/   # Route/page-level Views
│   │       │   └── widgets/   # Feature-specific subcomponents
│   │       └── repositories/  # OPTIONAL: local cache + sync only
│   └── main.dart              # App bootstrap and ProviderScope
└── pubspec.yaml
```

### Asset Guidelines

- Place static media files in `assets/` categorized by type: `images/`,
  `icons/`, and `animations/`.
- Register all asset directories under `flutter.assets` in `pubspec.yaml`.
- Never hardcode raw asset path strings directly in Views. Define and
  reference them as typed static constants in
  `lib/core/constants/app_assets.dart`.

### Working style

- Before implementing a feature, briefly state which layer(s) it touches
  and why.
- For a new feature, show the applicable chain:
  Model → Service → ViewModel → View.
- If a Repository is genuinely required, show:
  Model → Service → Repository → ViewModel → View.
- Do not introduce a Repository solely to satisfy the architecture.
- Flag explicitly, before writing code, if a request would require
  breaking this layering (e.g. calling Supabase directly from a widget).
- Keep feature code within its feature directory (`lib/features/<name>/`).
  Do not create large generic folders containing unrelated functionality.
  Do not scaffold every architectural layer folder up front — create them
  as features actually need them.

## AI Provider Integration

FaunaWatch supports Gemini, Groq, and OpenRouter.

Users provide and manage their own AI provider API keys. The mobile
application authenticates directly with the selected AI provider using the
user's own API key.

There are no shared or hardcoded FaunaWatch AI provider keys.

A user's AI API key is runtime user data, not application configuration.

- NEVER store API keys in source code, `.env` files, shared
  preferences/plain-text local storage, Git-tracked configuration, logs,
  or analytics.
- Use platform-backed secure storage (e.g. Keychain/Keystore-backed
  storage) for persistent API keys.
- Never send a user's AI provider API key to the FaunaWatch backend unless
  the architecture is explicitly changed and approved by the team.
- AI provider calls must be made through the Service layer and must never
  be initiated directly from Views or ViewModels.
- Abstract provider implementations behind a common interface so the app
  is not tightly coupled to one provider.
- Provider-specific request formats, models, capabilities, errors, and
  response structures must remain isolated inside their provider
  implementations.
- Do not assume Gemini, Groq, and OpenRouter support identical models,
  request formats, capabilities, or response structures.
- Tests must mock AI provider calls. Never allow `flutter test` or CI to
  make live calls to Gemini, Groq, or OpenRouter.
- API keys must never be logged or included in error messages, exception
  messages, debug output, crash reports, or analytics.
- Provider clients live in `lib/core/services/ai/` behind `AiVisionClient`.
  Gemini has its own client; Groq and OpenRouter share the OpenAI-compatible
  client. Each client can list its models and has a `defaultModel`, used
  until the user picks a model in Settings › AI Integration.
- The chosen provider and model (`AiPreferences`) are not secret but are
  stored per user in the same secure store as the keys, under
  `faunawatch.ai_pref.<userId>.*`.
- Photos sent to a provider are resized and have EXIF (including GPS)
  removed first (`AiPhotoService`). The possible-invasive hint comes only
  from the curated `species_reference` table, never from the AI.

## Security

Screenshots are blocked (Android `FLAG_SECURE` through `WindowSecurityService`)
only while the AI key screen (`AiKeySetupView`, onboarding and Settings › AI
Integration › manage keys) is open; it turns the block on and off itself. Every
other screen, including the Profile tab, allows screenshots.

Treat all API keys, tokens, passwords, credentials, and private user data
as secrets. Never commit them. Before adding a new config file, check
whether it could contain sensitive data — use placeholder/example configs
in docs instead of real-shaped values. API keys must never be logged, printed,
or included in exception or error messages.

## Coding Standards

Idiomatic, null-safe Dart. Use `const` constructors where practical.
Prefer composition over inheritance. Do not introduce a new state
management package or architectural pattern without first confirming it
fits what's listed under Tech Stack above.

Before adding a dependency: check if Flutter/Dart or an existing package
already covers it. Avoid dependencies for trivial functionality.

## Agent Behavior & Guardrails

Before modifying code:
1. Inspect the relevant existing files — don't assume a class/service/
   feature exists without checking.
2. Follow existing conventions; avoid duplicate implementations.
3. Keep changes scoped to the request — no unrelated refactors.

**When a decision would meaningfully affect architecture, or requirements
are unclear:** do not guess and proceed. Stop, leave a clear comment/TODO
at the point of ambiguity explaining the open question, and do not
continue implementing past it. This applies even when running
unattended — pausing means stopping work and flagging it, not silently
picking an interpretation.

**Git:** Work on a feature branch, never push directly to `main`. Do not
merge your own PR. Do not commit API keys, credentials, build artifacts,
or local machine config. Before committing, review `git status` and
`git diff`. Use clear, descriptive commit messages.

## Documentation

Google authentication uses the existing Supabase browser OAuth flow in
`lib/features/auth/` (Model → Service → ViewModel → View). Both auth screens
share `GoogleAuthAction`; it waits for a signed-in event before navigating.
`SupabaseGoogleAuthService` owns browser launch and loads the active session's
profile data. ViewModels choose navigation from that data. Startup restores
sessions through the splash ViewModel. Missing display names route to profile setup; named profiles route
to the shell. Android and iOS register `com.faunawatch.app://login-callback/`
and disable Flutter's default deep-link handler so Supabase's app_links can
process the PKCE callback. Enable Google in Supabase, configure a Google web
OAuth client, and allowlist that exact app redirect URL as described in README.
The Google client secret belongs only in Supabase provider settings. No new
dependency or database migration is required.

Private one-to-one Chats live in `lib/features/messages/`
(Model → Service → ViewModel → View). `SupabaseMessagesService` replaces the
sample inbox and conversations. Registered users can search community profile
names/handles and open the unique conversation for a pair. Only the two
participants can read its messages and private photos. Read/unread and inbox
deletion are per user; deletion hides the inbox entry, preserves history for
both users, and a new message restores the entry. Suspended users cannot open
chats, send messages, or upload chat photos. There is no admin message access.

Apply `20261104133813_create_private_chats.sql` before using Chats. It creates
the tables, checked RPCs, participant RLS, private `chat-images` bucket, and
Realtime publication entries. The user applies these scripts manually in the
Supabase SQL editor; agents must leave them in `supabase/migrations/` and must
not apply hosted changes. Existing prerequisite migrations must already be
applied. Chat photos have a 5 MB input/upload limit and are re-encoded from
pixels to WebP without EXIF/GPS through `ChatPhotoService`. Existing packages
cover gallery picking and encoding; no new dependency is needed. Private photo
URLs expire after one hour. Messages load in pages of 50; live subscriptions
refresh the active inbox/conversation and reconnect fetches missed messages.
Service replacement on account changes clears private state and cancels old
subscriptions. A failed send retains the current draft and selected photo.

In-app Notifications live in `lib/features/notifications/` (Model → Service →
ViewModel → View). `SupabaseNotificationsService` replaces the sample list and
reads the signed-in user's rows of `public.notifications`: newest first in pages
of 50 ("Load older notifications"), plus an unread count that also covers unloaded
rows. Live updates use Realtime on that table and refresh the list; the service
is replaced on account changes. Clients can only read, delete and set `read_at`
on their own rows (RLS and a column grant); rows are created only by
security-definer triggers: a report's owner is notified when it is approved,
declined/taken down (with the decline reason) or sent back with changes
requested (with the admin's message, never the admin); the owner of a report is
notified of a new comment by someone else; and the other participant of a chat is
notified of a new message, folded into one unread row per conversation, shown as
"Sent a photo" for photos, and skipped for suspended recipients. Relative times
("5m ago", "Yesterday") are formatted in the app from `createdAt` with an
injectable clock.

Further notifications: when a report enters `pending` (a new report, or the owner
resubmitting after changes were requested) its owner gets a `report_status`
notification ("Your report is pending review" / "Your resubmitted report is
pending review"). This is the one exception to the owner's-own-actions rule; an
admin withdrawing a change request does not notify. Likes create `report_like`
notifications for the report's owner, never for the owner's own like or an
unlike, grouped per report like chat: an existing UNREAD one is updated (title,
actor, time) instead of a new row ("<name> liked your report", then "<name> and
N others liked your report" by the number of likes from other users). The body
is the report's species, else its category (reports have no title column).

The list's header menu has "Clear all": after a confirmation dialog the service
deletes all of the user's notification rows (including unloaded older pages; RLS
allows deleting own rows) and the ViewModel empties the list and unread count.
The menu is hidden while the list is empty. Tapping a notification marks it read
and `NotificationsViewModel.open` returns the target (`notificationTargetFor`),
which the View navigates to: `report_status`, `report_comment` and `report_like`
open `ReportDetailScreen` in `lib/features/report_detail/` (Model → Service →
ViewModel → View) for that report id; comment notifications also open the
comments sheet. `SupabaseReportDetailService` loads the signed-in user's own
report in any status (pending, changes requested, approved, declined) through
owner RLS, signs its photos for one hour and shows the status clearly. Approved
reports reuse `FeedPostCard` with likes and comments from `FeedService.fetchPost`;
other statuses show photos and details. A deleted or missing report shows "This
report is no longer available". `chat_message` switches the shell to the Messages
tab (not a specific thread); `nearby_alert` and unknown types only mark read.

Apply `20261112090000_create_notifications.sql` before using Notifications. The
user applies it manually in the Supabase SQL editor; agents must not apply
hosted changes. It must be applied after `20261111150721_add_report_change_requests.sql`,
and it creates no notifications for past events. Pending and like notifications
need two more migrations, applied in this order after
`20261112100000_create_community_feed.sql` (which creates `report_likes`) and
`20261114041037_derive_report_ai_status.sql`:
`20261120090000_add_report_like_notification_type.sql` (only adds the
`report_like` enum value; run it on its own and let it finish, because Postgres
cannot use a new enum value in the transaction that added it) and then
`20261120090100_add_like_and_pending_notifications.sql` (the pending and like
trigger functions and the `notifications_report_ref` check now covering
`report_like`; re-runnable). The `nearby_alert` type exists so the app can
render it, but nothing generates it yet; that is pending the decision on the
`warning_zones` radius values and how proximity is generated (`alerts` is
unchanged and unused by the app). FaunaGuard's local device notifications are
separate from this server inbox; see below.

Push notifications live in `lib/features/push/` (Model → Service → ViewModel;
there is no View: the Settings switch and the shell use the ViewModel).
`PushMessagingService` wraps `firebase_messaging` (permission, token, token
refresh, launch message, tap while backgrounded) with `NoopPushMessagingService`
when Firebase is not configured; `SupabaseDeviceTokenService` calls the
`register_device_token` / `unregister_device_token` RPCs;
`SecurePushPreferencesService` keeps the per-DEVICE choice (default on) in
`flutter_secure_storage` under `faunawatch.push.enabled`. `PushViewModel` (kept
alive by `FaunaWatchApp`) registers this device's token on sign-in and on token
refresh when push is on and the user allowed notifications (Android 13+
`POST_NOTIFICATIONS`, declared in the manifest, and iOS), and unregisters it when
the switch is turned off; `SettingsViewModel.signOut` calls
`onBeforeSignOut` first so the token is removed while the session still works.
The Settings switch (`SettingsViewModel.togglePushNotifications`) is now real.
A tapped push (backgrounded or launching the app) carries `notification_id`,
`type`, `report_id`, `thread_id`; `PushPayload` feeds the existing
`notificationTargetFor` mapping, the notification is marked read through
`NotificationsService`, and `PushViewModel.pendingTarget` is consumed by
`ShellView` (so a cold start waits until the shell is shown) and opened with
`openNotificationTarget`, shared with the notifications list. Banners: the app
creates the high-importance (heads-up, sound, vibration) Android channel
`faunawatch_default` ("Notifications") at start (`initializeLocalNotifications`
in `main`), the manifest's `default_notification_channel_id` points to it, and
`send-push` sets `android.notification.channel_id` to it, so background pushes
pop up on screen. A push received in the foreground is shown by
`PushViewModel` through `LocalNotificationService` on Android only (same
channel, tag = `PushPayload.groupKey`, the same key `send-push` uses, so grouped
updates replace the banner; payload = the push data as JSON). Nothing is shown
when the Settings push switch is off. Tapping it, or launching the app from it,
follows the same `PushPayload` pending-target flow as a push tap. On iOS the
system presents foreground pushes
(`setForegroundNotificationPresentationOptions`), so no local notification is
posted. Server side: migration
`20261120100000_create_device_tokens.sql` (apply after the notification
migrations) adds `device_tokens` and the two RPCs, and the Edge Function
`supabase/functions/send-push/` (Deno; see its README) sends via FCM HTTP v1
for a Database Webhook on `notifications` INSERT and UPDATE (grouped refreshes
only), skips suspended users, groups by chat thread / report with a tag and
collapse id, and deletes dead tokens. Agents must not deploy it or apply
hosted changes. Still manual for the user: the Firebase project and config
files (both git-ignored: `android/app/google-services.json`, and
`ios/Runner/GoogleService-Info.plist`, which on a Mac is added to the Runner target
through Xcode; `keys/` holds only the service account JSON and webhook secret and
is never used by the build), the APNs key, the service account secret, the
`supabase secrets set` / `functions deploy` steps, the migration and the
webhook (README: "Enable push notifications"). The Android application ID and
iOS bundle ID are currently `com.example.faunawatch`. iOS has
`UIBackgroundModes: remote-notification` and `Runner.entitlements`
(`aps-environment`), configured but untested (Windows development).

The For You feed lives in `lib/features/feed/` (Model → Service → ViewModel →
View). Once a report is approved it appears there for every signed-in user,
newest approval first (`SupabaseFeedService` replaces the single sample post and
the local sample comments). `FeedViewModel` loads pages of 10, loads older ones
as the user nears the last post, supports pull to refresh, and signs out/in with
the account (the service is replaced on account changes). Posts are one
full-screen card each (swipe up for the next), with network photos, the title
(the user's species, else the AI's top guess, else the category label), the
description, category, AI severity/invasive flag (always with the "Preliminary
AI-assisted suggestions" note), and the place name. Private photo URLs and
uploaded avatars are signed for one hour (they refresh with the page).

My Gallery (`lib/features/gallery/`) appears directly below Profile's banner,
avatar, username and bio, in one scrollable page. Edit Profile, Change Theme and
Settings live in `ProfilePreferencesDrawer`, opened by the hamburger icon at
the top-right of the banner. Selecting an action closes the drawer before
opening the existing editor, theme picker or settings screen.
The system Back button on the shell (`ShellView`'s `PopScope`,
`ShellViewModel.back`) never closes the app at once: every bottom-tab and Feed
Map/For You change is remembered (up to 20 places), Back returns to the previous
one, then home (Feed › For You), and at home the first Back shows "Press back
again to exit" and only a second Back within 2 seconds closes the app.
`ShellViewModel.goTo(destination, feedTab:)` makes a combined jump one step;
sign-out calls `resetToHome()`, which also forgets the history. Screens pushed on
top of the shell keep their normal Back.
Gallery is absent from the feed tabs,
which contain Map and For You only. Gallery shows the signed-in user's approved,
pending AND declined reports, mixed in one three-column grid with yellow
title/date footers, newest submission first; changes-requested reports stay
out. Pending tiles carry a "Pending review" badge (clock icon) and declined tiles
a red "Declined" badge (`PostStatusBadge`) under every filter. Under the "My
Gallery" title, status chips All · Pending · Approved · Declined
(`GalleryStatusFilter`; All includes declined) combine with the Filter menu's report category
(`GalleryFilter`); the Filter button names the active category ("Filter · Animal
in need"). Both are applied by the server, so older matches are found, and each
filter has its own empty message (`GalleryState.emptyMessage`).
`SupabaseGalleryService` queries `reports` with `user_id = current user`, `status`
in the chosen statuses and the optional `category`, relying on existing owner RLS
(owners can read their own pending reports, photos and AI results), and loads
pages of 12 by submission time and ID, newest first. It returns `GalleryPost`
(a `FeedPost`, reused for title/category fallbacks, plus its `ReportStatus`) and
signs the first available private report photo for one hour.
`GalleryViewModel` owns its independent pagination, refresh and filters, and
discards superseded requests. Each filter (status chip + category) remembers its
loaded posts for the session: the first visit to a filter shows the skeleton, and
returning to it shows its posts at once while its newest page is fetched again in
the background and merged in (new posts appear; posts approved, declined or deleted
meanwhile leave it; older loaded pages are kept; a failed check keeps what is
shown). Everything is forgotten on account changes. `reload()` always starts over
(unlike pull to refresh, which is ignored while loading);
`CreatePostViewModel.submit` calls it after a successful submit when the gallery
is already open, so the new pending post appears. Every tile pushes a
profile-local full-screen `GalleryPostViewer` (TikTok-style vertical swiping under
a "My posts" bar), starting at the tapped post; it swipes through the gallery's
own posts, respecting its filters, and Back returns to the
existing profile/grid scroll position. Neither the shell destination nor the For
You tab/page changes. `GalleryPostViewModel` (keyed by `GalleryPostRef`: id,
the tile's `ReportStatus`, and an optional public-gallery author ID) loads
approved posts with photos and engagement through `FeedService.fetchPost`, checks
the current owner or the specified public author, and manages local likes and
comment counts. Pending and declined posts are not in that approved-only feed, so
they load through `ReportDetailService.fetchOwnReport` (owner RLS) with the
owner's profile name and avatar and show a large status badge. A declined post
also shows the admin's latest reason ("Reason: Duplicate report"), which
`fetchOwnReport` reads from `my_report_reviews()` (`DeclineReason`; a failed
lookup only hides the reason). Their like and comment buttons open a "This post
is still pending" or "This post was declined" dialog instead
(`showNotPublicPostDialog`; likes are also ignored by the ViewModel). A post
reviewed meanwhile loads from the feed if it was approved, shows as declined if
it was declined, and is otherwise unavailable. The shared post widgets accept action
callbacks; the comments sheet can notify this local ViewModel of changes. Full
post data is discarded when its page is disposed and on account changes.
Tapping a post's location in the viewer closes it and opens the map there (see
"Post location on the map" below). The grid's own query reads no location and
only the species guesses; the full AI analysis and the rounded point are read
when a single post is opened (`ownReportColumns` / `ownReportPost` in
`report_detail_service.dart`, which never read `user_notes` or
`responder_briefing`).
Scrolling or "Load older posts" loads more. While a filter's first page loads
(opening the gallery, a filter's first visit, or refreshing an empty grid)
`GallerySkeleton` shows pulsing placeholder tiles in the same three-column layout
(`galleryGridDelegate`) instead of a spinner; they stay still when the device asks
for less motion. No dependency or migration is added.

Public account profiles live in `lib/features/public_profile/`
(Model → Service → ViewModel → View). A post author's name/avatar, a chat
list name/avatar, and the conversation header name/avatar open a separate
`PublicProfileScreen`. In For You, tapping the signed-in user's own name/avatar
selects the existing Profile shell destination instead. The chat preview still
opens the conversation. Opening from the list does not mark it read; opening
from the conversation pauses its active/read state until Back, preserving the
draft. Opening another account preserves the shell destination, feed page and
the owner's gallery. Missing chat user IDs disable only the profile action.

Public profiles reuse `ProfileHeaderCard`, `GalleryHeader`, the three-column
gallery cards, and DM Sans/theme styles, with no preferences or pending-status
controls. `SupabasePublicProfileService` reads public identity through
`SupabaseProfileReaderService.findProfile` (null for a missing account) and
`public_profile_gallery()`. The ViewModel owns independent category filtering,
12-post pagination, refresh/retry, and rejects stale account/filter requests.
Both it and the auto-disposed full-post state clear on account changes. The
public gallery viewer swipes only that account's approved posts and returns to
the existing grid position. It reuses `GalleryPostViewModel` for full photos,
likes and comments; public references can never load pending or declined owner reports.

Apply `20261121233000_create_public_profile_gallery.sql` manually after
`20261112100000_create_community_feed.sql` and its prerequisites. Agents must
not apply hosted changes. This adds one gallery RPC and an index, no table or
notification changes. It filters by author, approved status and optional
category before keyset pagination by submission time/id, then reuses the
existing `community_feed()` projection, selecting gallery fields explicitly so
the feed's added AI/location columns do not change its return type. Reapply the
corrected gallery script if an older `select f.*` version is already installed.
It excludes coordinates, private notes and admin fields. It is executable only by
authenticated users and also checks `auth.uid()`; existing table RLS is unchanged.
Photo/avatar URLs reuse
the feed's one-hour signing and are not persisted. No new app dependency is
required. A local-only PostgreSQL permission/pagination check is in
`test/features/public_profile/public_gallery_security_test.cjs`; its PGlite
runtime is installed only under ignored `.dart_tool/public-profile-sql/`.

Apply `20261112100000_create_community_feed.sql` before using the feed. The user
applies it manually in the Supabase SQL editor; agents must not apply hosted
changes. It must be applied after `20261112090000_create_notifications.sql`. It
adds `community_feed()` (a security definer RPC: approved reports only, keyset
paging on approval time, i.e. the latest approving `report_reviews.decided_at`,
falling back to `created_at`, then `id`) and the `report_likes` table. Rules:
- **The feed shows the author's name and avatar.** This reverses the earlier
  "OQ 8: stay anonymous" decision (`20261027001000_restrict_location_and_images.sql`).
  Names use the same fallbacks as `list_chat_threads()` (username, full name,
  display name, "FaunaWatch user"); avatars are `profiles.avatar_path`, either
  `preset:<name>` or a signed `avatars` bucket path. Only the feed changed:
  `community_reports()` (the map) still returns no author, and the map's preview
  stays anonymous.
- **Location:** the feed returns `reports.place_name` exactly as stored (it is
  not split into city and province, because missing parts make that unreliable)
  and shows "Approximate location" when it is null. It never returns exact
  coordinates, and `user_notes` and the admin fields stay private. Since
  `20261121090000_add_ai_and_location_to_community_feed.sql` it also returns
  `latitude`/`longitude` rounded to 2 decimals (about 1 km), exactly like
  `community_reports()`, for the post's map link.
- **AI analysis:** every post with an AI result has an "AI analysis" button under
  its caption that opens `PostAiAnalysisSheet` (possible species with confidence,
  severity, condition, possible invasive with the matched species, summary,
  safety tips and community warning; empty sections are left out). The data is
  `FeedPost.aiAnalysis` (`PostAiAnalysis`). For other people's approved posts it
  comes from `community_feed()`, which returns `visual_condition_assessment`,
  `incident_summary`, `safety_recommendations`, `community_warning` and
  `invasive_match_name` only after the same 20261121090000 migration (applied by
  hand; until then the sheet shows only species, severity and the invasive flag).
  The app currently saves no summary or community warning, so those sections
  appear only if a later change fills them. `responder_briefing` and
  `user_notes` are never shown on posts.
- **Post location on the map:** tapping a post's location (For You, for posts
  with a rounded point, or any post in the gallery viewer) calls
  `CommunityMapViewModel.focusOnPost`, which switches the shell to Feed › Map at
  once as one Back step (`ShellViewModel.goTo`). The signed-in user's OWN post
  (any status) opens at its exact point, read on demand through owner RLS by
  `ReportDetailService.fetchOwnLocation` (`MapFocus.isExact`); it is held only in
  map state, drawn on the owner's device, and cleared on account changes.
  Everyone else's post opens at its rounded point (about 1 km), where its public
  pin is; public pins stay rounded for everyone. A failed exact lookup falls back
  to the rounded point. The camera moves there (zoom 14), waiting for the map's
  style if needed; an approved post's pin is refreshed in if missing, and the pin
  dialog is not opened automatically. The owner's exact point and their pending
  or declined posts get an orange marker (`MapboxMapService.showFocus`) and a
  banner "Only you can see this" explaining whether the spot is exact and whether
  others see a pin, removed by its close button, by opening someone else's post
  location, or on account changes. `FeedPost` itself always rounds coordinates.
  With FaunaGuard on, the next GPS fix recentres the map on the user.
- **Likes** are real: `report_likes` (report, user) rows that a user can add or
  remove only for themselves, only on approved reports and not while suspended.
  Counts and `liked_by_me` come from the RPC; the app likes optimistically and
  rolls back on failure. Likes notify the report's owner (see Notifications; migration
  `20261120090100_add_like_and_pending_notifications.sql`).
- **Comments** are real for every post: the app reads and writes
  `report_comments` (visibility and insert rules from
  `20261111144014_fix_comment_access_rules.sql`), so the `notify_report_comment`
  trigger notifies the report's owner. The table has no replies, reactions or
  photos, so the comments sheet offers plain text and emoji only, newest first
  (the latest 100; no paging yet).
- The community map's report pins open the matching post in the For You tab
  (`FeedViewModel.openReport`, fetching it through `community_feed(p_report_id)`
  when it is not loaded). The map shows only real approved reports at the
  approximate coordinates returned by `community_reports()`. It fits the first
  nonempty load into view; later refreshes preserve the current camera. There
  are no sample pins, simulated positions, or demo warning zones.
  Pin dialogs load the first available post photo on demand through
  `MapPostThumbnailViewModel` and the existing `FeedService.fetchPost` signed-URL
  flow. URLs are discarded when the dialog closes and reloaded on account
  changes. Previews stay anonymous and show a placeholder when no photo is
  attached or available; a failed photo load can be retried.

FaunaGuard lives in `lib/features/fauna_guard/`
(Model → Service → ViewModel → View), integrated into the community map.
It is opt-in, off by default, with a shield button beside Refresh and a
flip-card disclosure before permission requests. The map follows the live
device location with a blue marker while enabled. All approved reports from
the existing `community_reports()` RPC are watched, using approximate public
coordinates only: Getting closer at 1 km and Nearby at 500 m. Each report
alerts once per band per enabled session; simultaneous crossings are grouped.
Locations are approximate (~1 km precision); these are awareness estimates,
not exact wildlife positions. Device coordinates stay in memory and are not
uploaded or persisted by this feature. Reports refresh every minute while
enabled; failed refreshes and GPS/notification errors stop the session.

`DeviceGuardLocationService` reuses geolocator_android/geolocator_apple and
their platform interface. Do not add the umbrella geolocator package.
Android uses its location foreground service and wake lock, started from
the visible app with while-in-use location permission and an ongoing
notification; the app declares FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION,
WAKE_LOCK and POST_NOTIFICATIONS. iOS enables UIBackgroundModes/location and
background updates with a visible location indicator. Shared photo/map
behavior remains in its existing Services. `flutter_local_notifications`
22.x adds immediate Android/iOS system proximity notifications. When Android
push has initialized the shared plugin, FaunaGuard reuses it to preserve the
push tap handler and sets its own icon per notification. Android requires Java
desugaring and the retained ic_fauna_guard drawable. No FCM,
scheduled notifications, backend migration, warning_zones writes, or server
notification rows are added. Background operation continues while the session
and app process live, including across tabs and while locked; force-close,
OS termination and reboot do not restart tracking. Turning off, signing out,
or changing accounts cancels GPS/timers and clears location/alerts. Web
preview shows the intro but reports background tracking as mobile-only.
Verify background/locked operation on real Android/iOS devices before release.

Post creation lives in `lib/features/create_post/` (Model → Service → ViewModel →
View). A photo, a category and valid observation coordinates are required;
description/species/notes are optional. Reports are saved with `status = pending`.
Posting starts with the camera: the "+" in the bottom bar opens FaunaLens
(`lib/features/fauna_lens/`) instead of the form, and the top bar has no camera
button. The camera screen keeps its gallery option. After the "Happy with this
photo?" review, "Skip AI" goes to Create Post with the photo and no analysis, and
"Ask AI" opens "Choose animals" (`FaunaLensBoxesScreen`, `AnimalBoxesViewModel`).
There `SpeciesIdentificationService.findAnimals` asks the user's provider for a box
around each animal: `box_2d` as [ymin, xmin, ymax, xmax] on a 0–1000 scale, read
by `AnimalBox.listFromModelReply` into fractions of the photo. It uses the same
`AiVisionClient.describeImage` request as the analysis, so it works on all three
providers. Each box has its own colour (`AnimalBoxColor`, at most six boxes). A
single animal found is chosen automatically; the user can choose up to three
(`AnimalBox.maxChosen`, because `ai_analyses.possible_species` holds at most three)
and can draw boxes by hand. When nothing is found the screen offers "Draw a box" or
"Retake photo". The chosen boxes are drawn on the resized copy sent to the AI
(`AiPhotoService.prepare(boxes:)`) and listed by colour and position in the
prompt, which returns ONE combined analysis saved as ONE post: one animal gets up
to three ranked guesses; several get one best guess each (the reply's `box` colour
is only shown on screen, never saved); severity is the most urgent; there is one
category for the report; and every animal's guess is checked against
`species_reference` (the first match is kept). The species field gets the guesses
joined with commas. The AI Result offers "Use these results", "Analyse again"
(same photo and boxes) and "Retake photo". Boxes are never saved; there is no
database or admin site change.
"Use this photo?", "Choose animals" and "AI Result" follow the app's light/dark
mode and palette through `FaunaLensTheme` (light mode with Apollo keeps the
original FaunaLens colours; the live camera stays dark; animal box colours never
change). Their outlined buttons pass theme colours to `PillButton`'s optional
`secondaryFill`/`secondaryBorder`/`secondaryText`; other screens keep its white
outline.
Create Post is not a bottom-bar tab. FaunaLens ("Use these results" or "Skip AI")
opens `CreatePostView` as a page on top of "Use this photo?", so Back returns to
the photo (the bottom bar is hidden while posting). The page pops with a
`CreatePostExit`: `changePhoto` (the "Change photo" button on the photo, or the
"Add a photo" box after ✕ removed it) returns to the live camera, which also has
the gallery; `done` (after submitting) clears the draft, switches the shell to Feed
and closes FaunaLens; plain Back keeps the draft. Each "+" resets the draft, so a
post abandoned earlier is dropped (the reset happens in event handlers, never in
`dispose`, which Riverpod forbids). A new photo keeps what the user typed; its GPS
replaces the location, and a photo without GPS keeps a location the user chose
(map or current location) but not one from an earlier photo
(`CreatePostState.photoLocationLabel`). The form: a left-aligned "Create post"
title with an (i) button for posting tips and the safety reminder; the photo with
✕ at its top-right and "Change photo"; the AI analysis card (tinted, outlined);
Category, "What did you observe?", Species and notes as sign-up style fields
(`LabeledTextField`/`LabeledDropdownField` in `lib/core/widgets/`, theme-aware;
the sign-up `AuthTextField` is unchanged); and the observation location as a still
map picture with the pin (`LocationPreviewCard`). After submitting, the title is
"Post submitted for review", `AnimatedCheck` draws a check (finished at once when
the device asks for less motion), and "Done" goes home.
The map picture comes from the Mapbox Static Images API through
`LocationPreviewService` (`streets-v12` or `dark-v11`, a `1a5dc9` pin at zoom 14,
or the whole region without a pin before a location is chosen), using the same
public `MAPBOX_PUBLIC_TOKEN`; without a token a placeholder is shown. It uses the
Static Images allowance (50,000 free requests a month). Tapping the picture or its
full-screen button opens the existing `LocationPickerScreen`; "Use current
location" sits under it. The form no longer picks photos from the gallery itself
(`CreatePostViewModel.pickPhoto` was removed); photos come only through FaunaLens.
When the user chooses "use AI results" in FaunaLens, the analysis is carried into
Create Post with its photo, shown in a card that states it will be saved, and can
be detached there (`removeAiResult`; the form's species/category are kept). It is
dropped whenever the photo is removed or changed. On submit it is inserted into
`ai_analyses` as one write-once `completed` row while the report is still
`pending`, and the report gets `ai_status = completed`; without an attached
analysis `ai_status = unavailable`. If the insert fails, the report is rolled back.
The database derives `ai_status` from `ai_analyses`
(`20261114041037_derive_report_ai_status.sql`): a signed-in insert of `completed`
is stored as `pending` until the completed analysis row is inserted, which sets it
to `completed`; removing that analysis turns it `unavailable`; and a signed-in
update of `ai_status` that disagrees with `ai_analyses` raises `FW409
ai_status_mismatch`. Clients don't need to write it (the insert value from
`PostDraft.toRow` is harmless).
The report category comes from the AI result: prompt `fauna_lens_identify_v4`
picks among `animal_in_need`, `potentially_dangerous_animal` and
`other_wildlife_incident` (unknown or missing falls back to the last), and a
`species_reference` match forces "Possible invasive species" (never the AI).
`ai_analyses` has no category column; it is saved on `reports.category`. The
category is read-only while the analysis is attached, keeps its value when the
analysis is detached, and is then editable again.
Approved reports
are loaded for the map through `community_reports()`, preserving its approximate
coordinates and returning no author (the For You feed shows authors, see above). The map refresh action reloads approvals.
Observation locations are selected in a map picker (tap to pin, city/address
search, or current GPS); the form does not expose coordinate entry.
The picker opens in 3D and automatically centers on device GPS when available,
without changing the observation pin. Denied/unavailable GPS keeps the existing
location or regional fallback, with search and manual pinning still available.
The map service explicitly initializes that camera after the native map and style
are ready, independently of the GPS request, rather than relying only on the
widget's opening viewport.
Both map services share `applyMapLighting`: app dark mode uses Mapbox Standard's
night preset and light mode uses its day preset. The picker reapplies lighting
after style loads and theme changes without recentering or changing the pin.
Search uses Mapbox Geocoding v6 with `permanent=true` because the chosen coordinates are saved.
On submit, `PlaceNameService` makes one more permanent request, a reverse lookup of the
final point, to save its area in `reports.place_name` (barangay or locality, city, province;
never a street address). If it fails, the name stays null and the post still submits.
`place_name` is visible to the owner, admins and, for approved reports, in the For You feed (`community_feed()`, exactly as stored); `community_reports()` (the map) must not return it.
The `MAPBOX_PUBLIC_TOKEN` account must support permanent geocoding (a valid card
on file or an enterprise contract). `http` is a direct dependency for these
requests. Search runs on explicit submission; no request is sent per keystroke.
Photo uploads are re-encoded as WebP at quality 88 without EXIF, with extracted
GPS/device metadata stored separately in `report_image_exif`. `crypto` provides
SHA-256 fingerprints of the uploaded WebP bytes. `flutter_image_compress` 2.5.1+
supplies the Android/iOS WebP
encoder (including AGP 9 compatibility and iOS Swift Package Manager support).
Only a resized, metadata-free PNG in memory is passed to the encoder; the
uploaded file is `photo.webp` with MIME type `image/webp`. The bucket already
allows WebP, and existing uploaded files keep their original formats.
Post photos are limited to 5 MB
(5,242,880 bytes) for both input files and processed uploads. Files are uploaded
to the private `report-images` bucket; `report_images` stores their Storage paths
and metadata. Apply `20261103152000_limit_report_images_to_5mb.sql` to enforce
the same per-file limit in Storage. Existing objects are unaffected.

Appearance palettes (Apollo, Forest, Ocean, Sunset, Arctic and Meadow) are selected
in Profile > Change Theme. Apollo is the default and retains the original blue
controls, yellow highlights and green Material accents in both brightness modes.
`SettingsViewModel.activePaletteId` drives the shared light/dark theme providers
in `lib/core/theme/`; `AppPaletteColors` preserves the original UI colors for
Apollo and maps them to the generated scheme for other palettes. Light/Dark/System
remains an independent choice. Both appearance choices currently live in memory
for the app session; they are not saved to the profile or local storage.
No database change or new dependency is required.

Profile banners persist in `profiles.banner_asset` (preset asset identifier) or
`profiles.banner_color` (unsigned 32-bit ARGB stored as bigint), with at most one
set. Apply `20261028000100_add_profile_banner.sql` before running clients that
load or save banner preferences. Existing profiles may leave both fields null.

Update this file when introducing significant architectural changes,
new dependencies, or new configuration requirements. Keep it consistent
with the actual implementation — don't let it drift into aspiration.

## Important Project Rule

Do not invent project requirements. If implementation details are
unclear, inspect the repository and existing documentation first, then
follow the clarification protocol above rather than guessing.
