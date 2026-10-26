-- =============================================================================
-- Migration: extend_reports_and_images
-- Why: Add user-entered fields and device elevation to reports. Create
--      report_image_exif for EXIF metadata (GPS, device info, camera
--      settings). EXIF GPS is exact-location data so its RLS is
--      restricted to the report owner and admins.
--
-- TODO(open question): The EXIF-vs-reported-location distance threshold
--   for the admin site's "EXIF not verified" label is a display-layer
--   decision (500 m, configurable in the admin site), not a DB constraint.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- reports: new columns
-- ---------------------------------------------------------------------------

-- Device GPS altitude (metres). Nullable — not all devices provide it.
alter table public.reports
  add column if not exists elevation_m double precision;

-- User's own species identification (separate from AI result).
alter table public.reports
  add column if not exists user_species text;

-- Free-form notes from the user.
alter table public.reports
  add column if not exists user_notes text;

-- Field observation notes.
alter table public.reports
  add column if not exists perch_height_m double precision;

alter table public.reports
  add column if not exists host_tree text;

alter table public.reports
  add column if not exists is_night_observation boolean;

comment on column public.reports.elevation_m is
  'Device GPS altitude in metres. Nullable (not all devices provide it).';

comment on column public.reports.user_species is
  'User''s own species identification. Admins see this side by side with AI results.';

comment on column public.reports.user_notes is
  'Free-form notes from the user about the sighting.';

comment on column public.reports.perch_height_m is
  'User-entered perch height in metres (field observation note).';

comment on column public.reports.host_tree is
  'User-entered host tree species (field observation note).';

comment on column public.reports.is_night_observation is
  'Whether the sighting occurred at night (field observation note).';


-- ---------------------------------------------------------------------------
-- report_image_exif: EXIF metadata extracted from each photo
-- ---------------------------------------------------------------------------

create table if not exists public.report_image_exif (
  -- One row per image — image_id is the primary key.
  image_id          uuid primary key references public.report_images (id) on delete cascade,

  taken_at          timestamptz,

  -- EXIF GPS (exact location from the photo's metadata)
  gps_latitude      double precision check (gps_latitude  between -90  and  90),
  gps_longitude     double precision check (gps_longitude between -180 and 180),
  gps_altitude_m    double precision,

  -- Device info
  device_make       text,
  device_model      text,

  -- Camera settings (exposure, aperture, ISO — stored as free text since
  -- format varies by device)
  camera_settings   text,
  flash_fired       boolean,

  created_at        timestamptz not null default now()
  -- No updated_at: EXIF data is immutable (extracted once from the original photo).
);

comment on table public.report_image_exif is
  'EXIF metadata extracted from report photos. Contains exact GPS coordinates '
  'from the photo — this is privacy-sensitive and restricted to the report '
  'owner and admins. The mobile app reads EXIF before upload, inserts it here, '
  'then uploads a copy with EXIF stripped to the report-images bucket.';


-- ---------------------------------------------------------------------------
-- RLS — report_image_exif
-- ---------------------------------------------------------------------------

alter table public.report_image_exif enable row level security;

-- Select: report owner or admin only (EXIF GPS is exact location).
create policy "report_image_exif_select_owner_admin"
  on public.report_image_exif
  for select
  to authenticated
  using (
    public.is_admin()
    or exists (
      select 1
      from public.report_images ri
        join public.reports r on r.id = ri.report_id
      where ri.id = report_image_exif.image_id
        and r.user_id = (select auth.uid())
    )
  );

-- Insert: report owner only.
create policy "report_image_exif_insert_own"
  on public.report_image_exif
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.report_images ri
        join public.reports r on r.id = ri.report_id
      where ri.id = report_image_exif.image_id
        and r.user_id = (select auth.uid())
    )
  );

-- No update or delete policies — EXIF data is immutable once extracted.
