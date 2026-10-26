-- =============================================================================
-- Migration: harden_ai_analyses
-- Why: Users must not edit AI results. This migration:
--   - Drops the ai_analyses_update_own_report policy (DESTRUCTIVE)
--   - Restricts insert to pending reports only
--   - Adds a write-once trigger rejecting non-admin updates
--   - Adds species_origin column
--   - Adds admin select policy
--   - Documents the agreed possible_species and validation shapes
--
-- DESTRUCTIVE: drops ai_analyses_update_own_report (users lose update ability)
--
-- NOTE for the admin UI: because AI runs on the user's device with their own
-- key (AGENTS.md), RLS can make results write-once but cannot prove the first
-- write is genuine. The admin site should label it "AI analysis from the
-- reporter's device".
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Drop user update policy (DESTRUCTIVE)
-- ---------------------------------------------------------------------------

drop policy if exists "ai_analyses_update_own_report" on public.ai_analyses;


-- ---------------------------------------------------------------------------
-- Restrict insert: owner can insert only while report is pending
-- ---------------------------------------------------------------------------

drop policy if exists "ai_analyses_insert_own_report" on public.ai_analyses;
create policy "ai_analyses_insert_own_pending"
  on public.ai_analyses
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.id = ai_analyses.report_id
        and r.user_id = (select auth.uid())
        and r.status = 'pending'
    )
  );


-- ---------------------------------------------------------------------------
-- Write-once trigger: reject non-admin updates
-- ---------------------------------------------------------------------------

create or replace function public.guard_ai_analyses_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'AI analysis results are write-once and cannot be updated by non-admin users';
  end if;
  return new;
end;
$$;

create trigger guard_ai_analyses_update_trigger
  before update on public.ai_analyses
  for each row execute function public.guard_ai_analyses_update();

-- Admin update policy (so admins can correct AI results if needed).
create policy "ai_analyses_update_admin"
  on public.ai_analyses
  for update
  to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------------
-- Add species_origin column
-- ---------------------------------------------------------------------------

alter table public.ai_analyses
  add column if not exists species_origin public.species_origin;

comment on column public.ai_analyses.species_origin is
  'Biogeographic origin classification from the AI analysis. '
  'Orthogonal to possible_invasive: introduced does NOT mean invasive.';


-- ---------------------------------------------------------------------------
-- Admin select policy (admins always see all analyses)
-- ---------------------------------------------------------------------------

create policy "ai_analyses_select_admin"
  on public.ai_analyses
  for select
  to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------------
-- Documentation: agreed data shapes (no schema change needed)
-- ---------------------------------------------------------------------------

-- possible_species entries: {common_name: text, scientific_name: text, confidence: confidence_label}
--   Example: [{"common_name":"Philippine Eagle","scientific_name":"Pithecophaga jefferyi","confidence":"high"}]
--   Max 3 entries enforced by existing check constraint.

-- validation: array of {label: text, passed: boolean}
--   Example: [{"label":"image_relevant","passed":true}, {"label":"safe_content","passed":true}]

-- safety_recommendations: plain text (narrative paragraph from AI)

comment on column public.ai_analyses.possible_species is
  'Array of up to 3 candidate species. Each entry: '
  '{common_name: text, scientific_name: text, confidence: confidence_label}. '
  'Confidence is qualitative (high/medium/low/uncertain), never numeric.';

comment on column public.ai_analyses.validation is
  'Structured validation results. Array of {label: text, passed: boolean}. '
  'Example labels: image_relevant, safe_content, location_consistent.';

comment on column public.ai_analyses.safety_recommendations is
  'Plain text safety recommendations from the AI analysis. '
  'Displayed as prose, not a structured list.';
