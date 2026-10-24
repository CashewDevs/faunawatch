-- =============================================================================
-- Migration: create_ai_analyses
-- Why: Stores AI provider results for each report (SRS 3.1.3, 3.6.2, 3.7.3).
--      Includes possible_species (max 3, qualitative confidence), severity,
--      invasive flag, validation results, summaries, provider/model metadata,
--      and an input fingerprint enabling cache reuse across identical inputs.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.ai_analyses (
  id                        uuid primary key default gen_random_uuid(),

  report_id                 uuid not null references public.reports (id) on delete cascade,

  status                    public.ai_status not null default 'pending',

  -- null = undetermined (AI could not assess)
  animal_present            boolean,

  -- Array of up to 3 possible species. Each element: {name: text, confidence: confidence_label}
  -- Confidence is a qualitative label per SRS 3.6.2 — never a numeric probability.
  -- The check constraint enforces the SRS maximum of 3 candidates.
  possible_species          jsonb
                            check (
                              possible_species is null
                              or jsonb_array_length(possible_species) <= 3
                            ),

  visual_condition_assessment text,

  severity                  public.severity_level,

  -- Invasive species flag. Only set when an AI-suggested species matches the
  -- curated species_reference (SRS 3.6.2). Never a definitive determination.
  possible_invasive         boolean not null default false,
  invasive_match_species_id uuid references public.species_reference (id) on delete set null,

  -- Structured validation results: relevance, completeness, consistency,
  -- unsafe-content check. Shape is provider-dependent; stored as jsonb.
  validation                jsonb,

  -- Human-readable AI outputs (SRS 3.6.2)
  incident_summary          text,
  safety_recommendations    text,
  community_warning         text,
  responder_briefing        text,

  -- Provider / model metadata (SRS 3.6.2, 3.7.3)
  provider                  text,
  model                     text,
  prompt_version            text,

  -- Fingerprint of the input (report description + image hashes) used for
  -- cache reuse. Combined with (prompt_version, provider, model) to form the
  -- unique cache key.
  input_fingerprint         text,

  -- SRS disclosure requirement: always true for this prototype — every AI
  -- result must be shown with an appropriate disclosure to the user.
  is_preliminary            boolean not null default true,

  -- Nullable error detail for provider failures (timeout, rate-limit, etc.)
  error_code                text,

  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

comment on table public.ai_analyses is
  'AI analysis result for a report. One row per analysis attempt. '
  'Multiple rows may exist for the same report_id (e.g. retry after failure). '
  'Cache reuse is determined by the unique index on (input_fingerprint, prompt_version, provider, model).';

-- Trigger: keep updated_at current
create trigger ai_analyses_updated_at
  before update on public.ai_analyses
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists ai_analyses_report_id_idx
  on public.ai_analyses (report_id);

-- Cache-reuse unique index (SRS 3.7.3). Partial: only indexes completed rows
-- to avoid false cache hits on pending/failed analyses.
create unique index if not exists ai_analyses_cache_key_idx
  on public.ai_analyses (input_fingerprint, prompt_version, provider, model)
  where status = 'completed'
    and input_fingerprint is not null
    and prompt_version   is not null
    and provider         is not null
    and model            is not null;


-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.ai_analyses enable row level security;

-- Read: same visibility as the parent report (authenticated users for now).
create policy "ai_analyses_select_authenticated"
  on public.ai_analyses
  for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = ai_analyses.report_id
    )
  );

-- OPEN QUESTION (important): who writes to ai_analyses?
-- The SRS says all AI calls go through a backend (results written server-side),
-- but AGENTS.md says the app calls providers directly with user-supplied keys
-- (which would mean the Flutter client writes results). This is unresolved.
-- Conservative choice: allow the report owner to insert/update for now.
-- TODO(open question): once the write-path architecture is decided, replace
--   this with either a service_role / Edge Function policy (server-side writes)
--   or confirm the client-write model. See also SUPABASE_SCHEMA_TASK.md §5.
create policy "ai_analyses_insert_own_report"
  on public.ai_analyses
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.reports r
      where r.id = ai_analyses.report_id
        and r.user_id = auth.uid()
    )
  );

create policy "ai_analyses_update_own_report"
  on public.ai_analyses
  for update
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = ai_analyses.report_id
        and r.user_id = auth.uid()
    )
  );

-- Delete is intentionally not exposed to clients.
