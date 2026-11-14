# Task: "Request changes" in the App (Reporter Side)

**Read first:** `AGENTS.md` and `SUPABASE_MIGRATIONS.md`. Follow all rules in those files (MVVM: Model → Service → ViewModel → View, Riverpod, Supabase only through Services, tests mock Supabase).

**Owner:** Cliff (Flutter app). The database and the admin website are already done. This task is the app side only. **No new migration is needed.** If something below turns out to need a backend change, stop and raise it with the team. Don't work around it in the app.

Anything under **Open questions** is not decided. Don't guess. Use the conservative option, leave a `// TODO(open question): ...` comment, and list it in your PR description.

## What "Request changes" is

Before, an admin could only **approve** or **decline** a pending report. Now there is a third option: send it back to the reporter with a message saying what to fix. The reporter edits the post and resubmits it, and it goes back to the admin queue.

```text
pending ──(admin: Request changes)──► changes_requested
changes_requested ──(reporter: edit + Resubmit)──► pending
changes_requested ──(admin: Withdraw request)──► pending
pending ──(admin: Approve / Decline)──► approved / declined   (unchanged)
```

- Only **pending** posts can be sent back. Approved and declined posts stay final (an admin can still take down an approved post, as before).
- While a post is `changes_requested`, admins can't approve or decline it. They can only withdraw the request. A request is not a decision: no `report_reviews` row is written.
- There is no limit on rounds. A post can be sent back again after each resubmit (round 1, 2, ...).
- A post that is `changes_requested` is **not** on the map. Its photos are visible to the owner and admins only, and it can't get comments. All of those need `approved`.
- **The reporter never learns which admin sent the request.** The app has no way to read that, and must not try.

## What's already done

| Piece | Where | State |
|---|---|---|
| Database: new status, `report_change_requests` table, functions, policies | PR #43: `supabase/migrations/20261111150719_add_changes_requested_status_and_change_enums.sql`, `20261111150721_add_report_change_requests.sql` | Live on hosted |
| Comment access fix | PR #42: `20261111144014_fix_comment_access_rules.sql` | Live on hosted |
| In-app notifications (teammate) | PR #44: `20261112090000_create_notifications.sql` + `lib/features/notifications/` | Live on hosted |
| Admin website: Request changes dialog, history panel, Withdraw | `faunawatch-admin` PR #28 | Merged, **switch OFF** |

The admin site's **Request changes button stays disabled** until this app work ships. The switch is `requestChangesEnabled` in `faunawatch-admin/src/core/constants/featureFlags.ts`. Turning it on is a one-line admin PR (see Rollout). Until then, no real post can be sent back, so no reporter can get stuck.

### Notifications (already working)

When a post is sent back, the `reports_notify_status_change` trigger (`20261112090000_create_notifications.sql:221-300`) inserts a notification for the owner:

- `type = 'report_status'`, `report_id` = the post
- title `Changes requested on your report`
- body = the admin's message (from the open request)
- `actor_id = null`, so the admin stays hidden

The app already loads these. `NotificationItem.reportId` is mapped in `lib/features/notifications/models/notification_item.dart:48`. But **tapping a notification only marks it read**. Opening the report is a `TODO(open question)` at `lib/features/notifications/views/notifications_view.dart:97-106`, because reports have no route by id yet. This task should add that route (see step 3).

Things to know:

- **No notification is created** for withdraw or resubmit (status goes back to `pending`; the trigger skips `pending`, `:233`). So a "Changes requested" notification can point at a post that is no longer waiting. Always show the post's **current** status when it is opened from a notification.
- No notification goes to the owner for their own action (`:238`).

## Database facts you'll rely on

All facts below are verified against the migrations.

### Reading your own posts

- **Reports:** the owner can `select` all their own reports, every status, exact coordinates and `place_name` included. Policy `reports_select_owner_admin`, `20261027001000_restrict_location_and_images.sql:25-32`. Plain `.from('reports').select(...).eq('user_id', uid)` works.
- **Photos:** the owner can read their `report_images` rows and the files in the private `report-images` bucket in any status (`can_view_report_media`, `20261103155245_report_image_paths_without_user_id.sql:50-67`). Show them with `createSignedUrl` (the app already does this for avatars and chat photos, e.g. `lib/features/messages/services/messages_service.dart:147`).
- **AI analyses:** the owner can read their own `ai_analyses` (`ai_analyses_select_owner_admin_approved`, `20261027001000:122`).

### Reading the change request: `rpc('my_report_change_requests')`

`20261111150721_add_report_change_requests.sql:518-548`

```dart
final rows = await client.rpc(
  'my_report_change_requests',
  params: {'p_report_id': reportId}, // or omit / null for all your reports
);
```

It returns only the caller's reports, sorted by `report_id`, then `round`. Each row has these columns:

| column | type | meaning |
|---|---|---|
| `id` | uuid | request id |
| `report_id` | uuid | the post |
| `round` | int | 1, 2, ... per post |
| `message` | text | admin's message, 1–500 chars, already trimmed |
| `fields` | text[] | what to fix, any of `photos`, `species_description`, `location`, `category`; may be empty |
| `requested_at` | timestamptz | when it was sent ("waiting since") |
| `resolution` | text or null | `null` = **open**, `resubmitted`, `withdrawn` |
| `resolved_at` | timestamptz or null | when it was closed |

- There is at most one open request per post.
- The table itself has **no** policy for reporters (`.from('report_change_requests')` returns nothing for them). Always use the function.
- `species_description` covers species name, description and notes (`user_species`, `description`, `user_notes`).

### Reading decisions: `rpc('my_report_reviews')`

`20261112090100_hide_admin_identity_from_users.sql`. Approve, decline and take-down decisions on your own reports: `report_id`, `decision` (`approved` / `declined`), `decline_reason` (null unless declined), `decided_at`, oldest first. Same call shape as above (`p_report_id`, or omit for all your reports). Reporters can't read the `report_reviews` table itself, and the function never says which admin decided.

### Editing while `changes_requested`

The owner may edit while the post is `pending` (old rule) **or** `changes_requested`, as long as they are **not suspended**:

- **Report row:** `reports_update_own`, `20261111150721:233-250`. Editable columns the create form uses:
  - `category`
  - `latitude`, `longitude`
  - `description`, `user_species`, `user_notes`
  - `place_name`, if the location changed. Re-run `PlaceNameService.lookup` like `create_post_service.dart:49` does; it's billed, so only when the point moved.
- **Photos:** `can_edit_report_media`, `20261111150721:254-269`. It is used by the storage insert/update/delete policies (`20261103155245:107-139`) and the `report_images` insert/update/delete policies (`:157-183`).
- **EXIF:** `report_image_exif` can be inserted for the owner's image, but has **no update or delete policy**. It is deleted automatically when its `report_images` row is deleted (`20261027000600_extend_reports_and_images.sql:64, 101-130`).
- **Status cannot be changed by an update.** A trigger blocks it. Only the functions below move the status.

⚠️ **Guard every save with the status.** After an admin withdraws a request the post is `pending` again, and the database still lets the owner edit pending posts, so a plain update *succeeds*. Always update with `.update(...).eq('id', id).eq('status', 'changes_requested').select('id')`; an empty result means "not waiting for changes any more (or you're suspended)": stop and reload. Before any photo step, re-read the status and stop unless it is `changes_requested` (storage and `report_images` writes are also allowed on pending posts, so they won't fail on their own).

### Resubmitting: `rpc('resubmit_report')`

`20261111150721:427-507`

```dart
final photosChanged = await client.rpc(
  'resubmit_report',
  params: {'p_report_id': reportId},
) as bool;
```

In one transaction it closes the open request (`resolution = 'resubmitted'`) and moves the post `changes_requested → pending`.

It returns **`true` if the photos changed** since the request. The database detects any added, removed or replaced photo, whether in the `report_images` rows or in the storage files, including an in-place overwrite. In that case it has already:

- **deleted** the report's `ai_analyses` rows, and
- set `reports.ai_status = 'unavailable'`.

What to do with the boolean:

- **`true`:** if you have a fresh FaunaLens result for the new photo, save it **after** resubmit, now that the post is `pending` again. Owners may only insert `ai_analyses` while the post is pending (`ai_analyses_insert_own_pending`, `20261027000700_harden_ai_analyses.sql:31-43`).
  - Insert `analysis.toAnalysisRow(reportId)` (`lib/features/fauna_lens/models/ai_identification.dart:170`), exactly as `create_post_service.dart:92-97` does.
  - **Don't write `reports.ai_status`.** The database sets it to `completed` as soon as the completed analysis is inserted (`20261114041037_derive_report_ai_status.sql`).
  - Rows are write-once and there may be only one `completed` analysis per report (`20261103153902_one_completed_ai_analysis_per_report.sql:16-18`).
  - If the AI insert fails, the post simply stays `pending` with `ai_status = 'unavailable'`. Don't undo the resubmit.
- **`false`:** the existing analysis (if any) is kept. Don't insert a new one; if the post already has a completed analysis the insert fails (one-completed rule).

The checks run in this order: post exists → caller owns it → caller not suspended → post is `changes_requested`. Errors are in the table below.

## What the app needs

Suggested structure (adjust to fit). Chain: **Model → Service → ViewModel → View**.

### 1. Models (pure Dart)

- `ReportStatus` enum: `pending`, `changesRequested`, `approved`, `declined`, plus an `unknown` fallback.
  - Map unknown database values to `unknown`, **never** to pending. New statuses may be added later.
  - Labels: "Pending review", "Changes requested", "Approved", "Declined".
- `MyReport`: id, status, category, created_at, description / user_species / user_notes, coordinates, place_name, cover photo path, ai_status.
- `ChangeRequest`: the `my_report_change_requests` row.
  - `isOpen` = `resolution == null`.
  - `fields` mapped to an enum (`photos`, `speciesDescription`, `location`, `category`), dropping unknown values.
- `ReportEdit` / reuse of `PostDraft` for the edited values. `PostDraft.toRow` (`lib/features/create_post/models/post_draft.dart:53-72`) is for **insert**: it sets `status` and `ai_status`. Don't send those in the edit update; send only the edited columns. (An `ai_status` that disagrees with the post's analyses is refused with `FW409 ai_status_mismatch`.)

### 2. Services (Supabase only here)

- `MyReportsService`:
  - `fetchMyReports()`: select own reports + cover image path, newest first.
  - `fetchReport(id)`
  - `fetchChangeRequests(reportId)`: `rpc('my_report_change_requests')`.
- `ReportEditService`:
  - `updateDetails(reportId, edit)`: update the report row guarded with `.eq('status', 'changes_requested').select('id')`; empty means not waiting for changes any more (stop and reload).
  - `replacePhoto(reportId, newPhoto)`: see "Replacing the photo".
  - `resubmit(reportId)`: returns `photosChanged`.
  - `saveAnalysis(reportId, analysis)`: insert `ai_analyses` only. The database then sets `ai_status = 'completed'` itself.
- Map `PostgrestException.code` to a typed error (table below). Never put keys, tokens or ids in messages.

#### Replacing the photo

The create flow always uploads to the fixed path `{reportId}/photo.webp` without upsert (`create_post_service.dart:62-69`). A second upload to that path fails because the file exists. **Recommended:**

1. Prepare the new photo with `PostPhotoService.prepare` (WebP, no EXIF, 5 MB limit), the same as create.
2. Upload it under a **new file name**, e.g. `{reportId}/photo-<millis>.webp`. Any single file name after `{reportId}/` is accepted (`report_id_from_image_path`, `20261103155245:36-46`).
3. Insert a new `report_images` row with path, size and fingerprint, plus its `report_image_exif` row.
4. Delete the old `report_images` row (its EXIF row goes with it) and remove the old storage file. Between steps 3 and 4 the post briefly has two photos, so pick the cover as the newest `report_images` row (`created_at`).
5. If a step fails, clean up the new file/row, like the `catch` block in `create_post_service.dart:99-121`.

Why not overwrite in place (upload with `upsert: true` + update the row)? The EXIF row can't be updated, so it would keep the **old** photo's GPS/device data. The database would still detect the change either way.

### 3. ViewModels and Views

- **My posts list.** Every own report with a status chip: Pending review / Changes requested / Approved / Declined.
  - Put `changes_requested` posts first, or badge them, with a clear call to action ("Changes requested – tap to fix").
  - **Suggestion:** replace the placeholder **"Your Gallery"** tab (`lib/features/gallery/`, `GalleryView` used in `lib/features/feed/views/feed_view.dart:48`; `FaunaGalleryService` returns 12 fake items, `gallery_service.dart:9-28`). See Open questions.
  - Loading, empty and error states.
- **Report detail (route by report id).** Photos, details, current status, and:
  - **`changes_requested`:** a card with the open request: message, "what to fix" chips, "Waiting since {requested_at}", round number. Plus an **Edit and resubmit** button.
  - **Other statuses:** read-only. Optionally show past rounds.
  - **Never show or ask who the admin was.**
- **Notification tap.** Resolve the TODO at `notifications_view.dart:97-106`: for `report_status` / `report_comment` with a `reportId`, open the report detail. The report may have been deleted (row cascades) or have changed status; handle "not found".
- **Edit screen.** Reuse the create-post widgets: category, location picker, description / species / notes, photo, and FaunaLens if a new photo is taken.
  - Prefill from the report.
  - Highlight the fields in the request's `fields`, but allow editing everything.
  - Flow: Save the edits → **Resubmit** → if `photosChanged` and a new FaunaLens result exists, `saveAnalysis` → show "Sent back for review".
  - Decide whether Save and Resubmit are one button or two (Open questions).
- **Only offer editing for `changes_requested` posts.** The database also lets owners edit `pending` posts (an older rule, accepted for now). The app must not offer that, so a post can't change while an admin is reviewing it.

## Error handling

PostgREST returns function errors as HTTP 400 with the SQLSTATE in `error.code`. `42501` usually arrives as 403, or 401 when signed out. In Dart: `PostgrestException.code`, and `.message` for the text.

| `code` | `message` | When | Suggested copy |
|---|---|---|---|
| `42501` | `Only the reporter can resubmit a report` | Not the owner. A signed-out caller instead gets HTTP 401 `permission denied for function resubmit_report` (also `42501`) | "You can only resubmit your own posts." (signed out: send to sign-in) |
| `FW403` | `user_suspended` | Suspended user resubmits | "Your account is suspended, so you can't resubmit posts right now." |
| `FW404` | `report_not_found` | Post deleted | "This post no longer exists." |
| `FW404` | `change_request_not_found` | Inconsistent state (shouldn't happen) | "Something went wrong. Pull to refresh." |
| `FW409` | `report_not_awaiting_changes` | Already resubmitted, or an admin withdrew the request | "This post is no longer waiting for changes. It's been refreshed." **Reload it.** |
| `FW409` | `ai_status_mismatch` | The app wrote `reports.ai_status` and it disagrees with the post's analyses (app bug: the app shouldn't write it) | Generic error |
| `22023` | `Choose a report` | `p_report_id` was null (app bug) | Generic error |
| `42501` (insert/storage) | `new row violates row-level security policy`: Postgres `42501` for `report_images`/EXIF; a Storage error (403, row-level security) for files | User is suspended, or the post was deleted | "This post can't be edited any more." Reload. |
| update with 0 rows | (none) | The guarded update (`.eq('status', 'changes_requested')`) found nothing: request withdrawn or already resubmitted, user suspended, or post deleted | Same as above |

## Related changes you should know about

### Comments (PR #42, `20261111144014_fix_comment_access_rules.sql:92-137`)

The app's comments are still local samples (`lib/features/feed/services/post_comments_service.dart:20-24`). The backend now supports real ones:

- **Insert:** any signed-in, **non-suspended** user, on an **approved** report. Before PR #42 only the owner could, because of a bug.
- **Read:** non-removed comments on approved reports. On any other report, only the report owner, admins and the comment's author can read them.
- **Edit own:** only while the report is approved and you are **not** suspended.
- **Delete own:** always, except comments an admin removed. Those can't be seen or deleted by their author.
- Each new comment notifies the report owner (`20261112090000:307-343`).

Switching comments to `report_comments` is a separate task. It isn't required here.

### Suspensions

- Suspended reporters can't edit a `changes_requested` post and get `FW403` on resubmit.
- The app still doesn't explain suspensions anywhere (separate open item). For now, show the copy above.
- To explain one, read the user's own suspensions with `rpc('my_sanctions')`: `id`, `reason`, `created_at`, `ends_at` (null = until lifted), `lifted_at` and `is_active`, newest first. It never says which admin suspended them, and the `user_sanctions` table itself is admin-only.

## Testing

- **Unit/widget tests must mock Supabase** (AGENTS.md). Never hit the hosted project.
  - Follow `test/features/create_post/create_post_service_test.dart`: a real `SupabaseClient` pointed at a local fake `HttpServer` (`:123`).
  - Fakes for ViewModel tests follow `test/features/notifications/fake_notifications_service.dart`.
- Cover:
  - status mapping, including unknown values
  - parsing change requests (open vs resolved, unknown fields)
  - each error code above
  - a 0-row update
  - `photosChanged` true/false (AI insert only when true)
  - the photo replace cleanup on failure
- **Manual test against a LOCAL Supabase only:**
  1. `supabase start`, then `supabase db reset --local`. This applies every migration.
  2. Point the app's `SUPABASE_URL` / `SUPABASE_ANON_KEY` defines at the local stack (the `--dart-define`s read in `lib/core/constants/app_config.dart:13-22`; the Android emulator reaches the host as `10.0.2.2`).
  3. Sign up two users in the app: a reporter and an admin. Make the admin one an admin in local Studio (`http://127.0.0.1:54323`, SQL editor): `insert into public.admin_users (user_id) values ('<admin uuid>');`. Its `profiles` row is created on sign-up (`20261016120100_create_profiles.sql:48-64`). Admin actions need it.
  4. Create a post as the reporter (it is `pending`), then send it back as the admin in the local SQL editor:

     ```sql
     begin;
     select set_config('request.jwt.claims',
       '{"sub":"<admin uuid>","role":"authenticated"}', true);
     set local role authenticated;
     select public.admin_request_changes(
       '<report uuid>',
       'Please retake the photo in daylight.',
       array['photos']::public.report_change_field[]);
     commit;
     ```

     Or run the admin site's dev server against the same **local** stack: set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to the local values from `supabase status`, plus `VITE_ENABLE_REQUEST_CHANGES=true`, as environment variables in the terminal that starts it (they take priority over the env files). **Never** turn the switch on in a setup that points at the hosted project, and don't commit these values.
  5. Check:
     - the notification arrives
     - the post shows "Changes requested"
     - editing works and Resubmit returns to Pending
     - AI is cleared only when the photo changed
     - a withdraw (`admin_withdraw_change_request('<report uuid>')`) makes the app show "not waiting any more"
     - a suspended reporter is refused
- Run `flutter analyze`, `flutter test`, `dart format .` before the PR.

## Rollout

1. App PR (this task), reviewed and merged. Report it to the team.
2. Then a one-line admin PR turns the switch on (`requestChangesEnabled = true` in `faunawatch-admin/src/core/constants/featureFlags.ts`). Don't flip it before the app version that can resubmit is in testers' hands.
3. No database step is needed: everything above is already live.

## Open questions (for Cliff / the team)

1. **Where "My posts" lives:** replace the placeholder "Your Gallery" tab (suggested), or a list on the Profile screen? The profile has no post list today.
2. **One button or two:** "Save" and "Resubmit" separately (drafts saved between sessions), or a single "Resubmit" that saves and resubmits?
3. **FaunaLens on a new photo:** required before resubmit, optional, or not offered in the edit flow? The database allows any of these. Without a new analysis the post goes back with `ai_status = 'unavailable'`.
4. **Past rounds:** show the full history of requests to the reporter, or only the open one? `my_report_change_requests` returns all rounds.
5. **Withdraw has no notification.** Should the backend notify the reporter when an admin withdraws a request (a small migration for the team)? Until then the app should simply show the current status.
6. **Deleting a post while changes are requested:** the database allows owners to delete their reports in any status (`20261016120300_create_reports_and_images.sql:104-108`). Offer it here or not?
7. **Multiple photos:** the create flow has one photo. Keep one in the edit flow? (Assumed: one.)
8. **Push notifications** are not part of this (PR #44 is in-app only).
9. If the request is withdrawn mid-edit, photo steps already done stay on the (now pending) post. Accept that, or check status between steps (recommended)?
