-- =============================================================================
-- Migration: one_completed_ai_analysis_per_report
-- Why: Nothing stopped a report from having more than one completed
--      ai_analyses row (the owner can insert while the report is pending).
--      community_reports() left-joins the completed analysis, so such a
--      report came back twice, and readers had to guess which result was
--      the real one. A partial unique index now allows at most one
--      completed analysis per report. Pending and failed attempts are not
--      limited, so retrying after a failure still works.
--
-- No data is changed. If duplicates exist when this runs, creating the
-- index fails and the migration rolls back instead of deleting anything;
-- resolve them first. (Checked on the hosted project on 2026-11-03: 0.)
-- =============================================================================

create unique index if not exists ai_analyses_one_completed_per_report_idx
  on public.ai_analyses (report_id)
  where status = 'completed';

comment on table public.ai_analyses is
  'AI analysis result for a report. One row per analysis attempt. '
  'Multiple rows may exist for the same report_id (e.g. retry after failure), '
  'but at most one with status completed (ai_analyses_one_completed_per_report_idx). '
  'Cache reuse is determined by the unique index on (input_fingerprint, prompt_version, provider, model).';
