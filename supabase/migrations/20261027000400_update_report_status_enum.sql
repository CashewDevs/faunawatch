-- =============================================================================
-- Migration: update_report_status_enum
-- Why: Enum changes MUST be in their own migration because ALTER TYPE ... ADD
--      VALUE cannot be used in the same transaction that references the new
--      value. This migration:
--        1. Renames 'submitted' → 'pending' in report_status
--        2. Adds 'approved' and 'declined' to report_status
--        3. Creates decline_reason enum (5 agreed values)
--        4. Creates species_origin enum (3 agreed values)
--
-- DESTRUCTIVE: renames 'submitted' → 'pending'. Existing rows change value.
--   Non-breaking because 'submitted' was the only value and no code depends
--   on the literal string yet.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_status: rename 'submitted' → 'pending', add new values
-- ---------------------------------------------------------------------------

alter type public.report_status rename value 'submitted' to 'pending';
alter type public.report_status add value 'approved';
alter type public.report_status add value 'declined';


-- ---------------------------------------------------------------------------
-- decline_reason: moderation decline reasons (agreed set)
-- ---------------------------------------------------------------------------

create type public.decline_reason as enum (
  'inaccurate_species',
  'low_quality_photo',
  'domestic_specimen',
  'duplicate',
  'inaccurate_gps'
);


-- ---------------------------------------------------------------------------
-- species_origin: biogeographic origin classification from AI analysis
-- ---------------------------------------------------------------------------

-- TODO(open question): species_reference.status is still plain text. It
--   represents a different axis (conservation/invasive status) than
--   biogeographic origin. Formalize species_reference.status into its own
--   enum in a future migration once the team confirms the full vocabulary
--   (e.g. 'invasive', 'endangered', 'threatened', 'protected').

create type public.species_origin as enum (
  'endemic',
  'native',
  'introduced'
);
