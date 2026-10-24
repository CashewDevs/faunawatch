-- =============================================================================
-- Migration: create_warning_zones_and_alerts
-- Why: warning_zones stores the proximity radius configuration for each report
--      (SRS 3.1.2). alerts stores per-user proximity/area warning notifications
--      (SRS 3.1.4). Both are created here because they share a conceptual
--      grouping (proximity system) and have no mutual foreign key dependency.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- warning_zones
-- ---------------------------------------------------------------------------

create table if not exists public.warning_zones (
  id                  uuid primary key default gen_random_uuid(),

  report_id           uuid not null references public.reports (id) on delete cascade,

  -- Radius in metres for each warning level (SRS 3.1.2: Approaching / Near / Danger Zone).
  -- OPEN QUESTION: the specific radius thresholds are not defined in the SRS.
  -- Columns are nullable so they can be populated once values are confirmed.
  -- Do NOT hardcode radius numbers here — flag to user.
  -- TODO(open question): what are the Approaching / Near / Danger Zone radius
  --   values in metres? These must be confirmed before the proximity feature
  --   can be used. Optionally make them configurable per report category.
  approaching_radius_m  double precision check (approaching_radius_m > 0),
  near_radius_m         double precision check (near_radius_m > 0),
  danger_radius_m       double precision check (danger_radius_m > 0),

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table public.warning_zones is
  'Proximity radius configuration per report. '
  'Radius thresholds are pending team confirmation (see OPEN QUESTION).';

create trigger warning_zones_updated_at
  before update on public.warning_zones
  for each row execute function public.set_updated_at();

create index if not exists warning_zones_report_id_idx
  on public.warning_zones (report_id);


-- ---------------------------------------------------------------------------
-- RLS — warning_zones
-- ---------------------------------------------------------------------------

alter table public.warning_zones enable row level security;

-- Readable by any authenticated user (needed for map proximity display)
create policy "warning_zones_select_authenticated"
  on public.warning_zones
  for select
  to authenticated
  using (true);

-- Only the report owner can create/update warning zone config for their report
create policy "warning_zones_insert_own"
  on public.warning_zones
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.id = warning_zones.report_id
        and r.user_id = auth.uid()
    )
  );

create policy "warning_zones_update_own"
  on public.warning_zones
  for update
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = warning_zones.report_id
        and r.user_id = auth.uid()
    )
  );

-- Cascade delete via report; no explicit client delete policy needed.


-- ---------------------------------------------------------------------------
-- alerts
-- ---------------------------------------------------------------------------

create table if not exists public.alerts (
  id          uuid primary key default gen_random_uuid(),

  user_id     uuid not null references public.profiles (id) on delete cascade,
  report_id   uuid not null references public.reports  (id) on delete cascade,

  level       public.warning_level not null,
  message     text not null,

  -- null = unread; timestamptz = when the user marked it read
  read_at     timestamptz,

  created_at  timestamptz not null default now()
  -- No updated_at: alerts are immutable except for read_at (handled by update policy).
);

comment on table public.alerts is
  'Per-user proximity/area warning notifications. '
  'System-generated (trigger or server function). Clients only read and mark read. '
  'OPEN QUESTION: generation mechanism (trigger vs Edge Function vs client-side). '
  'Device push token storage is NOT included — confirm with team before adding.';

-- OPEN QUESTION: how alerts are generated is not specified in the SRS.
-- Options: database trigger, scheduled Edge Function, or client-side detection.
-- This table is created without a generation mechanism. Do not add a
-- device_tokens table until the user approves the push notification approach.
-- TODO(open question): decide alert generation path and push notification
--   token storage strategy before implementing the proximity feature.

create index if not exists alerts_user_id_idx
  on public.alerts (user_id);

create index if not exists alerts_report_id_idx
  on public.alerts (report_id);

-- Useful for "unread alerts" queries
create index if not exists alerts_user_unread_idx
  on public.alerts (user_id, read_at)
  where read_at is null;


-- ---------------------------------------------------------------------------
-- RLS — alerts
-- ---------------------------------------------------------------------------

alter table public.alerts enable row level security;

-- Users can only read their own alerts
create policy "alerts_select_own"
  on public.alerts
  for select
  to authenticated
  using (auth.uid() = user_id);

-- No client insert policy — alerts are system-generated.

-- Users can update their own alerts (mark as read)
create policy "alerts_update_own"
  on public.alerts
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Users can delete their own alerts (dismiss)
create policy "alerts_delete_own"
  on public.alerts
  for delete
  to authenticated
  using (auth.uid() = user_id);
