-- =============================================================================
-- Migration: create_species_reference
-- Why: Curated species/status reference used to validate "possible invasive
--      species" flags on AI analyses (SRS 3.6.2). Reference data belongs in a
--      migration (not only seed.sql) so it is present in every environment.
--      The pilot area and actual species list are NOT defined in the SRS, so
--      only the table is created here — no data is invented.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.species_reference (
  id              uuid primary key default gen_random_uuid(),

  common_name     text not null,
  scientific_name text not null,

  -- Minimal status field. At minimum supports marking a species as potentially
  -- invasive, which gates the possible_invasive flag on ai_analyses.
  -- TODO(open question): what full status vocabulary is needed?
  --   e.g. 'native', 'introduced', 'invasive', 'endangered'?
  --   Confirm with the team before expanding.
  status          text not null,

  pilot_area      text,
  -- OPEN QUESTION: the specific pilot area is not defined in the SRS.
  -- Column is nullable; populate via migration once confirmed.

  notes           text,

  created_at      timestamptz not null default now()
  -- No updated_at: reference data is updated via new migrations, not client edits.
);

comment on table public.species_reference is
  'Curated species/status reference for the pilot area. '
  'Used to validate possible_invasive flags in ai_analyses. '
  'Populated via migrations, not by clients.';

create index if not exists species_reference_status_idx
  on public.species_reference (status);


-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.species_reference enable row level security;

-- Authenticated users can read the reference (needed for species lookup in app)
create policy "species_reference_select_authenticated"
  on public.species_reference
  for select
  to authenticated
  using (true);
  -- NOTE: using (true) is appropriate here — this is public reference data for
  -- authenticated users, analogous to a read-only lookup table.

-- No insert / update / delete policies for clients.
-- All changes go through migrations or a service_role function.
