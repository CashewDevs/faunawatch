-- =============================================================================
-- Migration: create_reports_and_images
-- Why: Core reporting tables. reports stores the user's sighting/incident.
--      report_images stores metadata for uploaded photos (files live in
--      private storage). Both tables must exist before ai_analyses and
--      community_responses can reference them.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- reports
-- ---------------------------------------------------------------------------

create table if not exists public.reports (
  id           uuid primary key default gen_random_uuid(),

  user_id      uuid not null references public.profiles (id) on delete cascade,

  category     public.report_category not null,
  description  text,

  -- User-adjusted GPS location (SRS 3.1.2: GPS-captured, manually adjustable).
  -- OPEN QUESTION: PostGIS vs plain columns. Defaulting to plain double precision
  -- with check constraints. Enable postgis and switch to geography/geometry only
  -- if the user approves.
  -- TODO(open question): approve PostGIS if geospatial query performance becomes
  --   a concern at scale (distance queries, clustering). For prototype (<=1,000
  --   reports) plain columns with a btree index are sufficient.
  latitude     double precision not null
               check (latitude  between -90  and  90),
  longitude    double precision not null
               check (longitude between -180 and 180),

  status       public.report_status not null default 'submitted',
  -- TODO(open question): see report_status enum — expand values once the full
  --   status lifecycle is confirmed with the team.

  ai_status    public.ai_status not null default 'pending',

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.reports is
  'User-submitted wildlife sighting/incident reports. '
  'Each report may have multiple images and one ai_analyses row.';

-- Trigger: keep updated_at current
create trigger reports_updated_at
  before update on public.reports
  for each row execute function public.set_updated_at();

-- Indexes
-- Foreign key index
create index if not exists reports_user_id_idx
  on public.reports (user_id);

-- Spatial approximation index for nearby-report queries.
-- A composite (lat, lon) btree index covers bounding-box queries efficiently
-- at prototype scale. Replace with a PostGIS spatial index if approved.
create index if not exists reports_location_idx
  on public.reports (latitude, longitude);

-- Filter by status / ai_status
create index if not exists reports_status_idx
  on public.reports (status, ai_status);


-- ---------------------------------------------------------------------------
-- RLS — reports
-- ---------------------------------------------------------------------------

alter table public.reports enable row level security;

-- OPEN QUESTION: report visibility.
-- The SRS has a shared community map but also requires location data to be
-- protected from unauthorized access (SRS 3.5). Whether other users can see
-- exact or approximate coordinates is not decided.
-- Conservative placeholder: any authenticated user can read any report.
-- TODO(open question): narrow this policy once the visibility model is
--   confirmed — e.g. only the owner, or approximate coords for non-owners.
create policy "reports_select_authenticated"
  on public.reports
  for select
  to authenticated
  using (true);

-- Users can create their own reports
create policy "reports_insert_own"
  on public.reports
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Users can update their own reports
create policy "reports_update_own"
  on public.reports
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Users can delete their own reports
create policy "reports_delete_own"
  on public.reports
  for delete
  to authenticated
  using (auth.uid() = user_id);


-- ---------------------------------------------------------------------------
-- report_images
-- ---------------------------------------------------------------------------

create table if not exists public.report_images (
  id            uuid primary key default gen_random_uuid(),

  report_id     uuid not null references public.reports (id) on delete cascade,

  -- Path inside the private report-images storage bucket.
  -- Convention: {auth.uid()}/{report_id}/{filename}
  storage_path  text not null,
  content_type  text not null,
  size_bytes    bigint not null check (size_bytes > 0),

  -- SHA-256 (or similar) hash of the image file. Used by ai_analyses to
  -- determine whether a cached result can be reused (SRS 3.7.3).
  fingerprint   text not null,

  created_at    timestamptz not null default now()
  -- No updated_at: images are immutable once uploaded (replace = delete + insert).
);

comment on table public.report_images is
  'Metadata for images attached to a report. '
  'Actual files live in the private report-images storage bucket.';

create index if not exists report_images_report_id_idx
  on public.report_images (report_id);

create index if not exists report_images_fingerprint_idx
  on public.report_images (fingerprint);


-- ---------------------------------------------------------------------------
-- RLS — report_images
-- ---------------------------------------------------------------------------

alter table public.report_images enable row level security;

-- A user can read images if they can read the parent report.
-- This mirrors the report visibility policy (authenticated users for now).
create policy "report_images_select_authenticated"
  on public.report_images
  for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_images.report_id
      -- When report select policy is narrowed, this check will automatically
      -- restrict image access to the same set of viewers.
    )
  );

-- Only the report owner can attach images
create policy "report_images_insert_own"
  on public.report_images
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.id = report_images.report_id
        and r.user_id = auth.uid()
    )
  );

-- Only the report owner can update image metadata (rare, but allowed)
create policy "report_images_update_own"
  on public.report_images
  for update
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_images.report_id
        and r.user_id = auth.uid()
    )
  );

-- Only the report owner can delete images
create policy "report_images_delete_own"
  on public.report_images
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_images.report_id
        and r.user_id = auth.uid()
    )
  );
