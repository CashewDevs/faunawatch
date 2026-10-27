# Task: Admin, Moderation, Comments and Privacy Schema Changes

**Read first:** `AGENTS.md`, `SUPABASE_MIGRATIONS.md`, and `SUPABASE_SCHEMA_TASK.md`. Follow all rules in those files. This task adds new migrations on top of the initial schema (`20261016120000` to `20261016120700`) and the Dart changes the mobile app needs to fill the new columns.

## Background

The FaunaWatch admin website (`faunawatch-admin` repo) reviews community reports. A read-only review of the hosted database (2026-10-25) found that it matches the 8 committed migrations, and that:

- There is no admin role anywhere, so nothing in the database grants admin access.
- Reports have no moderation workflow (`report_status` only has `submitted`).
- Any signed-in user can read every report's exact coordinates and every report photo.
- Report owners can insert and update `ai_analyses`, so they could edit AI results.
- Comments, suspension, usernames and EXIF data do not exist yet.

The decisions below were agreed by the project owner. Do not change them without asking. Anything under **Open questions** must not be guessed: use the conservative option, leave a `-- TODO(open question): ...` comment, and list it in your summary.

## Ground Rules

1. The existing 8 migrations are applied and recorded on the hosted project. **Never edit them.** Every change is a new file made with `supabase migration new <name>`.
2. One logical group per migration, in the order under "Migration Plan".
3. `alter type ... add value` cannot be used in the same transaction that uses the new value. Keep enum changes in their own migration, before the migrations that use them.
4. Every new table gets RLS enabled in the same migration, with explicit per-operation policies.
5. Every `security definer` function sets `search_path = ''` and uses schema-qualified names. Use `(select auth.uid())` inside policies.
6. Verify with `supabase db reset`. Applying to the hosted project (`supabase db push`) is a human-approved step.
7. Flag destructive or behaviour-changing steps (dropped policies, renamed enum values) before writing them.

## Agreed Decisions

| Topic | Decision |
|---|---|
| Admin role | `public.admin_users` table (no client policies) plus `public.is_admin()` security definer function. Not a `profiles` column, because `profiles_update_own` would let users promote themselves. Only role is admin; the admin website only accepts admin accounts. |
| Report status | `pending`, `approved`, `declined`. Admin approval is part of the product. |
| Decline reasons | `inaccurate_species`, `low_quality_photo`, `domestic_specimen`, `duplicate`, `inaccurate_gps` |
| Category | Keep the 4 SRS incident categories. No animal-group column. |
| Severity | Keep the SRS 5 levels in the database. The admin site maps them to 3 for display. |
| Confidence | Keep the qualitative label. No numeric confidence. |
| Species origin | `endemic`, `native`, `introduced` |
| AI results | Users cannot edit AI results. Users can submit their own identification and notes (`user_species`, `user_notes`); admins see both side by side. |
| Location captured | Reported coordinates plus device elevation. EXIF data from the photo. Field notes. |
| Comments | Users can comment on posts (the only user-to-user interaction; no messaging). Admins can flag or remove comments with a note. |
| Avatars | Preset avatars use a distinguishable value: `preset:<name>` (for example `preset:bunny`). Uploaded avatars keep the storage path `{user_id}/{filename}`. |
| Emails for admins | Admin-only RPC (not an Edge Function). |
| Verified badge | Means the email is confirmed (`auth.users.email_confirmed_at`). Turn on **Confirm email** in the hosted Auth settings. |
| Community location precision | Other users see approved reports snapped to a ~1 km grid (2 decimal places). Owners and admins see exact coordinates. |
| Google sign-in | Mobile and admin may both use it. One email = one user (Supabase links identities with the same verified email). Provider setup is dashboard config, not a migration. |
| Username | Separate `username` (unique) and `full_name` columns on `profiles`. |
| Suspension | Suspended users can still sign in (to see why) but cannot create reports, comments or community responses. |

## Migration Plan (in order)

### 1. `create_admin_users`

```sql
create table if not exists public.admin_users (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
-- Intentionally no client policies: only is_admin() and the dashboard read/write this table.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  );
$$;

revoke execute on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
```

The first admin is added by the project owner: create the user under **Authentication**, then insert its id into `admin_users` in the SQL Editor (data, not schema).

### 2. `harden_grants_and_functions`

- Revoke all privileges on public tables from `anon` (no anon policies exist, so nothing breaks), and set default privileges so future tables do not grant `anon` either.
- Recreate `handle_new_user()` with `set search_path = ''` and `public.profiles` qualified.

### 3. `extend_profiles`

- Add `username text unique` (nullable until set; consider a format check) and `full_name text`.
- Update the signup flow so the username goes to `username`, not `display_name`. Leave `display_name` in place; dropping it is destructive and needs approval.
- Add a check or comment documenting the `preset:<name>` convention for `avatar_path`.

### 4. `update_report_status_enum` (enum changes only)

- `alter type public.report_status rename value 'submitted' to 'pending';` (keeps existing rows).
- `alter type public.report_status add value 'approved';` and `add value 'declined';`
- Create `public.decline_reason` enum with the 5 agreed values.
- Create `public.species_origin` enum: `endemic`, `native`, `introduced`.

### 5. `create_moderation`

- `reports.status` default becomes `pending`. Change `reports_insert_own` so new rows must have `status = 'pending'`.
- Owners can edit only `pending` reports. Change `reports_update_own` (both `using` and `with check`) to require `status = 'pending'`, so approved and declined reports are locked for owners. Owners keep delete.
- Guard trigger so only admins can change status:

  ```sql
  create or replace function public.guard_report_status()
  returns trigger
  language plpgsql
  security definer
  set search_path = ''
  as $$
  begin
    if new.status is distinct from old.status and not public.is_admin() then
      raise exception 'Only admins can change report status';
    end if;
    return new;
  end;
  $$;
  ```

- `report_reviews`: one row per decision (`id`, `report_id`, `decision` (approved/declined), `decline_reason` (required when declined), `decided_by` → `auth.users`, `decided_at`). Select/insert for `is_admin()` only. The report owner may read the decision and decline reason for their own report.
- `admin_notes`: `id`, `report_id`, `author_id`, `body`, `created_at`. All operations `is_admin()` only. Report owners must never read these.
- RPC `admin_decide_report(report_ids uuid[], decision, decline_reason)`: checks `is_admin()` first, inserts the review rows and updates `reports.status` in one transaction (supports bulk actions).

### 6. `extend_reports_and_images`

- `reports`: `elevation_m double precision` (device GPS altitude, nullable), `user_species text`, `user_notes text`, and the user-entered field notes `perch_height_m double precision`, `host_tree text`, `is_night_observation boolean`.
- `report_image_exif` (one row per image): `image_id` → `report_images`, `taken_at timestamptz`, `gps_latitude`, `gps_longitude`, `gps_altitude_m`, `device_make`, `device_model`, `camera_settings text` (exposure, aperture, ISO), `flash_fired boolean`. Select: report owner and admins only (EXIF GPS is an exact location). Insert: report owner.

### 7. `harden_ai_analyses`

- Drop `ai_analyses_update_own_report`.
- Change insert so the owner can insert only while the report is `pending`.
- Add a trigger that rejects updates from non-admin clients, making rows write-once.
- Add `species_origin public.species_origin` (nullable). Leave `species_reference.status` as it is: reference status and biogeographic origin are separate concepts.
- JSONB conventions (no column change; document them in a `comment on column`):
  - `possible_species`: array of at most 3 `{common_name, scientific_name, confidence}`, where `confidence` is a `confidence_label` value.
  - `validation`: array of `{label, passed}` (`passed` is a boolean).
  - `safety_recommendations` stays plain text.
- Note for the admin UI: because AI runs on the user's device with their own key (`AGENTS.md`), RLS can make results write-once but cannot prove the first write is genuine. The admin site labels it "AI analysis from the reporter's device".

### 8. `create_comments`

- `report_comments`: `id`, `report_id`, `user_id` → `profiles`, `body text not null`, `created_at`, `updated_at`.
- `comment_moderation` (admin only): `comment_id` primary key → `report_comments`, `is_flagged boolean`, `note text`, `removed_at timestamptz`, `moderated_by`, `updated_at`. Only admins flag comments; users have no report-comment action.
- Select: anyone who can see the report, excluding removed comments (use a security definer helper to check `comment_moderation`). Admins see all.
- Insert: own row, not suspended, report is approved. Update/delete: own row.

### 9. `create_user_sanctions`

- `user_sanctions`: `id`, `user_id`, `reason text`, `created_by`, `created_at`, `ends_at timestamptz` (null = until lifted), `lifted_at`. Admin-only writes. A user may read their own sanctions.
- `public.is_suspended(uid uuid)` security definer helper.
- Add `not public.is_suspended((select auth.uid()))` to the insert policies on `reports`, `report_comments` and `community_responses`.

### 10. `restrict_location_and_images`

This changes who can see what. Flag it to the user before applying.

- `reports` select: owner or `is_admin()` only. Replace `reports_select_authenticated`.
- RPC `community_reports(min_lat, min_lng, max_lat, max_lng)`: security definer, returns **approved** reports only, with `round(latitude, 2)` / `round(longitude, 2)` (~1 km) and no exact coordinates. It is anonymous: no `user_id` and no reporter profile fields. Use it for the community map and proximity warnings.
- `report_images`, `ai_analyses` select: owner, admins, or the parent report is approved.
- Storage `report-images` select: owner folder, `is_admin()`, or the report in path segment 2 (`{user_id}/{report_id}/{file}`) is approved. Replace `report_images_storage_select`.
- Avatars: `preset:` values are not storage paths; the bucket policy is unchanged.

### 11. `create_admin_rpcs`

All check `is_admin()` first and raise if false.

- `admin_list_users()`: profile fields, `email` and `email_confirmed_at` from `auth.users`, report count, current sanction.
- `admin_sector_stats(from_ts, to_ts, cell_deg default 0.1, min_count default 3)`: groups sightings into fixed grid cells (0.1° is about 11 km), returns the **cell centre** (never an average of points) and counts per cell, and omits cells with fewer than `min_count` sightings.
- Admin select policies (`using (public.is_admin())`) on tables the admin site reads that are not already covered above.

## Mobile App (Dart) Changes

Follow `AGENTS.md` layering: Supabase access in Services only, models updated with tests, Supabase mocked.

1. **Signup/profile:** write `username` and `full_name`; write `preset:<name>` for preset avatars.
2. **Report submission:**
   - Capture device elevation with the coordinates.
   - Let the user enter their own species identification, notes and field notes (perch height, host tree, night observation).
   - Read EXIF from each photo into `report_image_exif`, then **upload a copy with EXIF stripped** to `report-images`. Otherwise the photo leaks the exact GPS location the 1 km grid is meant to hide.
3. **AI analysis:** insert the result once; never update it.
4. **Community map:** read through `community_reports(...)`, not the `reports` table.
5. **Comments:** list, add, edit and delete own comments; hide removed ones.
6. **Suspension:** show a clear message when an insert fails because the user is suspended.

## Dashboard Settings (Not Migrations)

- Authentication → Providers → Email: turn on **Confirm email**.
- Google provider setup will come with the admin site's Google sign-in task.

## Resolved Questions (2026-10-27)

The project owner answered these. They are already reflected in the migration plan above.

| # | Question | Resolution |
|---|---|---|
| 1 | Can owners edit decided reports? | No. Owners can edit only `pending` reports (migration 5). |
| 2 | Who flags comments? | Admins only (migration 8). |
| 3 | `species_reference.status` vs `species_origin`? | Keep separate: reference status is not biogeographic origin (migration 7). |
| 4 | Extend the `possible_species` shape? | Yes: `{common_name, scientific_name, confidence}`. JSONB convention, no schema change (migration 7). |
| 5 | Invasive threat type? | Leave it out until its source is decided. Do not add a column. |
| 6 | `validation` shape and `safety_recommendations` format? | `[{label, passed}]` for validation; plain text for safety recommendations (migration 7). |
| 7 | Grid cell size and minimum count? | 0.1° (about 11 km) and 3, as function defaults (migration 11). |
| 8 | Should community reports include the reporter's profile? | No. Anonymous, to protect reporter privacy (migration 10). |
| 9 | EXIF GPS distance threshold? | 500 m. This is admin-site display logic, not a database constraint. |

## Still Open

- Invasive threat type (`colony`, `aquatic`, `ecosystem`, `biosecurity`): no source yet. Leave it out and mention it in your summary.

## Definition of Done

- [ ] New migrations only, made with the CLI, in the order above
- [ ] `supabase db reset` passes locally
- [ ] RLS enabled with explicit policies on every new table; admin access only through `is_admin()`
- [ ] No client can change `reports.status`, AI results, admin notes, comment moderation or sanctions unless admin
- [ ] Exact coordinates, EXIF GPS and unapproved photos readable only by owner and admins
- [ ] Dart models, services and tests updated; `dart format .`, `flutter analyze`, `flutter test` pass
- [ ] Remaining open items flagged in comments and in the summary
- [ ] Nothing pushed to the hosted project without approval, nothing committed to `main`
