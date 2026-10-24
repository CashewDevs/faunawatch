-- =============================================================================
-- FaunaWatch — Local / Dev Seed Data
-- =============================================================================
-- This file is for LOCAL DEVELOPMENT ONLY (supabase db reset applies it last).
-- Do NOT add real user data or real-shaped credentials here.
-- Reference data required in ALL environments (e.g. species_reference rows)
-- belongs in a migration, not here.
--
-- SUPABASE_MIGRATIONS.md: "Reference data the app genuinely requires in every
-- environment ... belongs in a migration, not only in seed.sql."
-- =============================================================================

-- Insert example species_reference rows for local testing.
-- These are illustrative only — the real pilot-area species list must be
-- confirmed by the team and added in a migration.
-- TODO(open question): replace with real pilot-area species list once confirmed.

insert into public.species_reference (common_name, scientific_name, status, pilot_area, notes)
values
  ('Burmese Python',      'Python bivittatus',    'invasive', 'Pilot Area A', 'Seed data — local dev only'),
  ('Monitor Lizard',      'Varanus salvator',     'native',   'Pilot Area A', 'Seed data — local dev only'),
  ('Philippine Eagle',    'Pithecophaga jefferyi', 'endangered', 'Pilot Area A', 'Seed data — local dev only')
on conflict do nothing;
