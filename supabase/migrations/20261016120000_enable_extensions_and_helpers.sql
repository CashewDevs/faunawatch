-- =============================================================================
-- Migration: enable_extensions_and_helpers
-- Why: Define all shared enums and the updated_at maintenance trigger that
--      every editable table in the schema will reuse. Creating them here keeps
--      subsequent migrations clean and avoids duplication.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

-- Incident categories (SRS 3.1.2)
create type public.report_category as enum (
  'animal_in_need',
  'potentially_dangerous_animal',
  'possible_invasive_species',
  'other_wildlife_incident'
);

-- Report submission status
-- OPEN QUESTION: the SRS does not define the full set of report statuses.
-- Using a minimal placeholder set. Flag to user before adding more values.
create type public.report_status as enum (
  'submitted'
  -- TODO(open question): what additional statuses does the workflow require?
  --   e.g. 'under_review', 'resolved', 'closed'? Confirm with the team.
);

-- AI processing status (SRS 3.6.2, 3.3.1)
create type public.ai_status as enum (
  'pending',
  'completed',
  'unavailable',
  'failed'
);

-- Qualitative confidence label (SRS 3.1.3, 3.6.2) — never a numeric value
create type public.confidence_label as enum (
  'high',
  'medium',
  'low',
  'uncertain'
);

-- Severity (SRS 3.6.2)
create type public.severity_level as enum (
  'low',
  'moderate',
  'high',
  'critical',
  'uncertain'
);

-- Warning proximity levels (SRS 3.1.2)
create type public.warning_level as enum (
  'approaching',
  'near',
  'danger_zone'
);

-- Community response type (SRS 3.1.4)
create type public.response_type as enum (
  'can_assist',
  'feedback'
);

-- Community response status
-- OPEN QUESTION: allowed status values are not defined in the SRS.
-- Using a minimal placeholder set.
create type public.response_status as enum (
  'active'
  -- TODO(open question): what lifecycle states does a community response need?
  --   e.g. 'withdrawn', 'acknowledged'? Confirm with the team.
);


-- ---------------------------------------------------------------------------
-- updated_at trigger function
-- Reused by every table that has an updated_at column.
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
