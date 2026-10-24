# Task: Create the Initial FaunaWatch Supabase Schema as Migrations

**Read first:** `AGENTS.md`, `SUPABASE_MIGRATIONS.md`, and the FaunaWatch SRS (v01.00, 09/04/2026). Follow all rules in those files. This task only covers the database layer (`supabase/migrations/`). Do **not** change Dart code unless the user asks.

## Goal

Create the initial database schema for FaunaWatch as a series of Supabase CLI migrations, derived strictly from the SRS. The schema must support this flow:

**Account → Report → AI-Assisted Analysis → Map/Warnings → Community Response**

## Ground Rules

1. Use `supabase migration new <name>` for each file. Do not hand-name timestamps.
2. Create **one migration per logical group**, in the order listed under "Migration Plan". Do not put everything in one file.
3. Enable RLS on every table in the same migration that creates it, with explicit per-operation policies.
4. Do not invent requirements. Anything marked **OPEN QUESTION** below must not be guessed: add a `-- TODO(open question): ...` comment where it applies, use the conservative option described, and list it in your final summary for the user.
5. Do not store AI provider API keys anywhere in the database (`AGENTS.md`: users supply their own keys; they are never sent to the backend).
6. Verify with `supabase db reset`. Do not run `supabase db push` or touch the hosted project.
7. State your plan (tables, relationships, policies) to the user before writing SQL.

## SRS Constraints That Shape the Schema

- Species identification returns **up to three** possible species, never one definitive answer (SRS 3.1.3, 3.6.2).
- Confidence is a **qualitative label**: `High`, `Medium`, `Low`, `Uncertain`. Never a numeric/calibrated probability column.
- Severity values: `Low`, `Moderate`, `High`, `Critical`, plus `Uncertain`.
- Incident categories: Animal in need, Potentially dangerous animal, Possible invasive species, Other wildlife incident.
- Warning levels: `Approaching`, `Near`, `Danger Zone`.
- AI status must support **Pending** and **Unavailable** so a report is always stored even if all AI providers fail (SRS 3.6.2, 3.3.1).
- "Possible invasive species" is only allowed when an AI-suggested species matches the curated species/status reference. It is a flag, never a definitive determination.
- AI results are stored with **provider and model metadata**, prompt version, and a **fingerprint** so unchanged reports can reuse a cached result (SRS 3.6.2, 3.7.3).
- User location data and uploaded images must only be accessible through authorized requests (SRS 3.5).
- Community response means "I can assist / provide feedback". It is **not** a dispatch or emergency commitment (SRS 3.1.4).
- Prototype scale: ≥100 users, ≥20 concurrent, ≥1,000 reports. Keep the design simple; do not over-engineer.

## Proposed Schema

Treat column lists as the starting point. Add `id uuid primary key default gen_random_uuid()`, `created_at timestamptz not null default now()`, and `updated_at` (with trigger) where rows are editable. Use enums or `check` constraints for the fixed value sets above.

### 1. `profiles` (SRS 3.1.1)
- `id uuid` primary key, references `auth.users(id) on delete cascade`
- `display_name text`
- `avatar_path text` (path in the avatar storage bucket)
- Auto-create a row on signup via a trigger on `auth.users`.
- Passwords are handled by Supabase Auth (hashed). Do **not** create a password column.
- **OPEN QUESTION:** the SRS says "basic credentials and personal details" without listing fields. Only add `display_name` and `avatar_path` unless the user specifies more.

### 2. `reports` (SRS 3.1.2)
- `user_id` → `profiles(id)`
- `category` (the 4 categories)
- `description text`
- `latitude`, `longitude` (the user-adjusted reported location; GPS-captured and manually adjustable)
- `status` (submitted report status the user can view)
- `ai_status` (`pending`, `completed`, `unavailable`, and any other states you need; document them)
- **OPEN QUESTION:** the allowed values for report `status` are not defined in the SRS. Use only a minimal placeholder set (e.g. `submitted`) and flag it.
- **OPEN QUESTION:** PostGIS vs plain lat/long columns. Default to plain `double precision` latitude/longitude with check constraints and an index, unless the user approves enabling `postgis`.
- Users can create, edit, and delete **their own** reports only.

### 3. `report_images`
- `report_id` → `reports(id) on delete cascade`
- `storage_path text`, `content_type`, `size_bytes`
- `fingerprint text` (hash of the image, used for AI result caching)
- Image files live in a **private** storage bucket (see Storage).

### 4. `species_reference` (curated species/status reference)
- `common_name`, `scientific_name`
- `status` (at minimum a way to mark potentially invasive)
- `pilot_area text` (the SRS says the reference is for a selected pilot area)
- `notes text`
- Readable by authenticated users; writable only by admins/migrations (no client write policy).
- **OPEN QUESTION:** the pilot area and the species list itself are not in the SRS. Create the table only. Do not invent species data.

### 5. `ai_analyses` (SRS 3.1.3, 3.6.2)
- `report_id` → `reports(id) on delete cascade`
- `status` (`pending`, `completed`, `unavailable`, `failed`)
- `animal_present boolean` (nullable: null means undetermined)
- `possible_species jsonb` (array of **max 3** entries, each `{name, confidence}` where confidence is one of the 4 labels; enforce the max-3 limit with a `check` constraint on `jsonb_array_length`)
- `visual_condition_assessment text`
- `severity` (the 5 values)
- `possible_invasive boolean` and `invasive_match_species_id` → `species_reference(id)` (nullable)
- `validation jsonb` (relevance, completeness, consistency, unsafe-content check results)
- `incident_summary text`, `safety_recommendations text`, `community_warning text`, `responder_briefing text`
- `provider text`, `model text`, `prompt_version text`
- `input_fingerprint text` (report/image fingerprint)
- `is_preliminary boolean not null default true` (SRS disclosure requirement; keep it always true for now)
- `error_code text` (nullable, for provider failures such as timeout or rate limit)
- A **unique index** on `(input_fingerprint, prompt_version, provider, model)` to support cache reuse.
- **OPEN QUESTION (important):** the SRS says all AI calls go through a backend and results are cached there, but `AGENTS.md` says the app calls providers directly with user-supplied keys. So who writes to this table (the app client or a server function) is undecided. Write the table and the **read** policy (report owner and users allowed to view the report). For **insert/update**, add a policy limited to the report owner, with a `TODO(open question)` comment, and flag it to the user.

### 6. `warning_zones` (SRS 3.1.2)
- `report_id` → `reports(id) on delete cascade`
- `radius_meters` for each level (e.g. `approaching_radius_m`, `near_radius_m`, `danger_radius_m`)
- **OPEN QUESTION:** the radius thresholds for Approaching / Near / Danger Zone are not in the SRS. Do not hardcode numbers. Leave columns nullable or put a clearly marked placeholder default, and flag it.
- Proximity detection and clustering are **query-time** concerns. Do not create a clusters table. Add an index on report location to support nearby queries.

### 7. `community_responses` (SRS 3.1.4)
- `report_id` → `reports(id) on delete cascade`
- `user_id` → `profiles(id)`
- `response_type` (e.g. `can_assist`, `feedback`)
- `note text`
- `status` (response status that can be tracked)
- Unique constraint so a user has at most one active response per report, unless the user says otherwise.
- **OPEN QUESTION:** allowed `status` values are not defined. Use a minimal set and flag it.

### 8. `alerts` (SRS 3.1.4: proximity and area warning notifications)
- `user_id` → `profiles(id)`
- `report_id` → `reports(id) on delete cascade`
- `level` (`approaching`, `near`, `danger_zone`)
- `message text`
- `read_at timestamptz` (nullable)
- Users can only read and update (mark read) **their own** alerts.
- **OPEN QUESTION:** how alerts are generated (database trigger, scheduled function, or client-side) and whether push notification tokens are needed are not specified. Create the table only. Do not create a device-token table without the user's approval.

## Migration Plan (in order)

1. `enable_extensions_and_helpers`: shared enums, the `updated_at` trigger function
2. `create_profiles`: table, signup trigger, RLS
3. `create_species_reference`: table, RLS (read-only for clients)
4. `create_reports_and_images`: `reports`, `report_images`, indexes, RLS
5. `create_ai_analyses`: table, cache unique index, constraints, RLS
6. `create_warning_zones_and_alerts`: tables, indexes, RLS
7. `create_community_responses`: table, RLS
8. `create_storage_buckets_and_policies`: buckets and `storage.objects` policies

Adjust the order only if a foreign key dependency requires it.

## Storage (migration 8)

- `report-images`: **private**. Authenticated users can upload to a path prefixed by their own `auth.uid()`. Read access only for users who are allowed to see the related report.
- `avatars`: **OPEN QUESTION** whether avatars should be public or private. Default to private and flag it.
- Set a sensible file size limit and restrict allowed MIME types to images.

## RLS Policy Guidelines

| Table | Select | Insert | Update | Delete |
|---|---|---|---|---|
| `profiles` | authenticated users | own row (via trigger) | own row | none |
| `reports` | authenticated users (see note) | own | own | own |
| `report_images` | same as parent report | own report only | own report only | own report only |
| `species_reference` | authenticated users | none | none | none |
| `ai_analyses` | same as parent report | see open question | see open question | none |
| `warning_zones` | authenticated users | own report only | own report only | own report only |
| `community_responses` | authenticated users | own | own | own |
| `alerts` | own | none (system-generated) | own (mark read) | own |

**Note on report visibility (OPEN QUESTION):** the SRS has a shared community map, but also requires location data to be protected from unauthorized access. Whether other users see exact or approximate coordinates is not decided. Implement "authenticated users can read reports" as a **placeholder**, add a `TODO(open question)` comment, and ask the user. Do not make reports readable by anonymous users.

## Output Expected From You

1. The migration files, created via the CLI and tested with `supabase db reset`.
2. A short summary containing:
   - Tables created and their relationships
   - Every **OPEN QUESTION** you hit and the conservative choice you made
   - Anything in the SRS that you could not map to the schema
3. A note on anything that conflicts between the SRS and `AGENTS.md`.

## Definition of Done

- [ ] Migrations follow the order above, one logical group each
- [ ] RLS enabled with explicit policies on every table
- [ ] Enums or checks enforce: 4 categories, 3 warning levels, 5 severity values, 4 confidence labels, max 3 species
- [ ] No numeric confidence columns, no password columns, no AI key storage
- [ ] Storage buckets are private and created in a migration
- [ ] `supabase db reset` passes locally
- [ ] All open questions flagged in code comments and in the summary
- [ ] Nothing pushed to the hosted project, nothing committed to `main`
