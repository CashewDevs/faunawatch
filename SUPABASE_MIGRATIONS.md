# FaunaWatch — Supabase Migrations Guide for AI Agents

This file extends `AGENTS.md`. Where the two overlap, `AGENTS.md` wins. Read both before touching anything under `supabase/`.

## Core Rule

**The `supabase/migrations/` folder is the single source of truth for the database schema.**

Every schema change must be written as a SQL migration file committed to Git. Never describe, suggest, or assume changes made by hand in the Supabase Dashboard (Table Editor, SQL Editor, Storage UI, Auth UI). If a change is not in a migration file, it does not exist as far as the project is concerned.

This keeps the schema documented, reviewable in PRs, and reproducible by every teammate.

## What Must Go Through Migrations

- Tables, columns, indexes, constraints, enums, views
- Functions, triggers, and RPCs (Postgres functions)
- Row Level Security (RLS) enabling and all policies
- Storage buckets and storage policies
- Extensions (e.g. `postgis` if used for location queries)
- Seed/reference data that the app requires to function (see "Seed Data")

## Folder Layout

```text
faunawatch/
└── supabase/
    ├── config.toml          # Supabase CLI config (commit; contains no secrets)
    ├── migrations/          # Timestamped SQL migrations (append-only)
    │   └── 20261016120000_create_profiles.sql
    └── seed.sql             # Local/dev seed data only
```

Do not scaffold other folders unless a feature needs them. This folder lives at the repo root, outside `lib/`.

## Workflow for Any Schema Change

1. **State the plan first.** Briefly say what tables/policies/functions are affected and which Dart layer(s) will consume them (Model → Service → ViewModel → View, per `AGENTS.md`).
2. **Create the migration file with the CLI**, never by hand-naming a timestamp:
   ```bash
   supabase migration new <short_snake_case_description>
   ```
3. **Write the SQL** in the generated file (see conventions below).
4. **Test locally** by resetting the local database so every migration replays from scratch:
   ```bash
   supabase start
   supabase db reset
   ```
5. **Update the Dart side** if needed: models in `lib/features/<feature>/models/`, service access in the Service layer only. Views and ViewModels never talk to Supabase directly.
6. **Commit** the migration together with the related Dart changes on a feature branch. Never push to `main`.

Applying to the hosted project (`supabase db push`) is a **deliberate, human-approved step**. Do not run it, and do not run anything that targets the remote/production project, unless the user explicitly asks.

## Migration Rules

- **Append-only.** Never edit, rename, reorder, or delete a migration that has been committed/merged. If something is wrong, write a **new** migration that fixes it.
- **One logical change per migration**, with a descriptive name (`create_reports_table`, `add_severity_to_reports`, `add_reports_rls_policies`).
- **Idempotent where reasonable**: prefer `create table if not exists`, `create index if not exists`, `drop policy if exists` before recreating, etc.
- **Destructive changes** (`drop table`, `drop column`, `alter column ... type`, `delete`) must be flagged to the user before writing, with a note on data impact. Do not include them silently.
- **No secrets** in migrations, seeds, or `config.toml`. This includes AI provider API keys: per `AGENTS.md`, users supply their own keys and they are never sent to or stored in the backend. Do not create columns, tables, or functions that store them.
- **Never hardcode real user data** or real-shaped credentials in seed files.

## SQL Conventions

- Tables and columns: `snake_case`, plural table names (`reports`, `profiles`).
- Primary keys: `uuid` with `default gen_random_uuid()` unless there is a reason not to. Tables tied to a user reference `auth.users(id)` with an explicit `on delete` behavior.
- Include `created_at timestamptz not null default now()` and, where rows are edited, `updated_at` (with a trigger to maintain it).
- Use `check` constraints or enums for fixed value sets (e.g. report category, severity, AI status) rather than free text.
- Add indexes for foreign keys and for columns used in frequent filters (e.g. location or status queries).
- Put a short SQL comment at the top of each migration explaining **why** the change exists.

## Row Level Security (Mandatory)

- **Every table in the `public` schema must have RLS enabled in the same migration that creates it:**
  ```sql
  alter table public.reports enable row level security;
  ```
- Never ship a table with RLS enabled but no policies unless it is intentionally inaccessible to clients, and say so in a comment.
- Write explicit policies per operation (`select`, `insert`, `update`, `delete`) scoped to `auth.uid()` where appropriate. Avoid blanket `using (true)` policies; if one is truly needed (e.g. public reference data), justify it in a comment.
- Never rely on the `service_role` key from the mobile app. It must never appear in the Flutter code or any client-shipped config.
- The SRS requires that user location data is protected from unauthorized access and that uploaded images are only reachable through authorized requests. Policies for `reports` and storage must reflect this.

## Storage

Buckets and their policies are created in migrations (via SQL on `storage.buckets` and `storage.objects`), not through the Dashboard. Image buckets should be **private** by default, with policies tying object access to the owning user or an authorized-viewer rule.

## Seed Data

- `supabase/seed.sql` is for **local development only**.
- Reference data the app genuinely requires in every environment (for example, the curated species/status reference from the SRS) belongs in a migration, not only in `seed.sql`. Ask the user which data is which if unclear.

## Dashboard Drift

If the user says they (or a teammate) changed something in the Dashboard, do not ignore it and do not guess the SQL. Suggest capturing it:

```bash
supabase db pull          # or: supabase db diff -f <name>
```

Then review the generated file, clean it up, and commit it as a normal migration.

## Dart Integration Reminders

- Supabase access (queries, auth, storage, RPC calls) lives in the **Service layer** only (`lib/core/services/` or `lib/features/<feature>/services/`).
- When a table changes, update the corresponding Dart model and its tests. Tests must mock Supabase; `flutter test` must never hit a live project.
- Run `dart format .`, `flutter analyze`, and `flutter test` before considering Dart changes complete.

## When to Stop and Ask

Per the clarification protocol in `AGENTS.md`, do not guess and keep going. Stop, leave a clear `-- TODO(open question): ...` comment in the migration (or a `// TODO` in Dart), and flag it to the user when:

- A requirement behind a table, column, or policy is not in the SRS or existing docs
- A change would be destructive or alter existing data
- A policy decision affects who can see location data, images, or other users' reports
- The change would require breaking the layering (e.g. a View calling Supabase directly)
- The SRS and `AGENTS.md` conflict (for example, the SRS says AI calls go through a backend, while `AGENTS.md` says the app calls providers directly with user-supplied keys; `AGENTS.md` is the current rule)

Do not invent schema requirements. If it is not specified, inspect the repo and docs, then ask.

## Quick Command Reference

```bash
supabase start                              # Start local stack (needs Docker)
supabase migration new <name>               # Create a new migration file
supabase db reset                           # Rebuild local DB from all migrations + seed
supabase db diff -f <name>                  # Generate a migration from local schema changes
supabase db pull                            # Capture remote/Dashboard changes as a migration
supabase migration list                     # Compare local vs remote migration history
supabase db push                            # Apply to hosted project (human-approved only)
```

## Definition of Done for a Schema Change

- [ ] Migration file created via the CLI and committed (never an edit to an old migration)
- [ ] `supabase db reset` succeeds locally
- [ ] RLS enabled with explicit policies on every new table
- [ ] No secrets or real user data in any committed file
- [ ] Dart models/services updated and tested (Supabase mocked)
- [ ] `dart format .`, `flutter analyze`, `flutter test` pass
- [ ] Destructive or ambiguous parts flagged to the user
- [ ] `AGENTS.md` updated if this introduced a new dependency or configuration requirement
