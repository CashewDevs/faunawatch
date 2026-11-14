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
- FaunaLens photo capture: `camera` (live preview), `exif` (location of gallery
  photos), and `geolocator_android` + `geolocator_apple` through
  `geolocator_platform_interface` (location of captured photos). Their
  permissions are declared in `AndroidManifest.xml` and `Info.plist`. Do not
  depend on the `geolocator` package itself: its Linux plugin pulls in
  `package_info_plus`, which either fails on AGP 9 built-in Kotlin or conflicts
  with `flutter_secure_storage` 9.
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
injectable clock. Tapping a notification only marks it read for now: opening the
related report or chat is a TODO (no route by report id, and the chat screen
needs the other user's name and avatar).

Apply `20261112090000_create_notifications.sql` before using Notifications. The
user applies it manually in the Supabase SQL editor; agents must not apply
hosted changes. It must be applied after `20261111150721_add_report_change_requests.sql`,
and it creates no notifications for past events. Push notifications (FCM,
device tokens, an Edge Function) are NOT implemented: this is in-app only, and
no push package or `device_tokens` table exists. The `nearby_alert` type exists
so the app can render it, but nothing generates it yet; that is pending the
decision on the `warning_zones` radius values and how proximity is generated
(`alerts` is unchanged and unused by the app).

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
  coordinates, and `user_notes` and the admin fields stay private.
- **Likes** are real: `report_likes` (report, user) rows that a user can add or
  remove only for themselves, only on approved reports and not while suspended.
  Counts and `liked_by_me` come from the RPC; the app likes optimistically and
  rolls back on failure. There are no like notifications.
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

Post creation lives in `lib/features/create_post/` (Model → Service → ViewModel →
View). A category and valid observation coordinates are required; photos and
description/species/notes are optional. Reports are saved with `status = pending`.
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
The report category comes from the AI result: prompt `fauna_lens_identify_v3`
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
