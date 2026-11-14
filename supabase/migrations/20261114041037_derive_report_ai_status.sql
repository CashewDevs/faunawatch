-- =============================================================================
-- Migration: derive_report_ai_status
-- Why: reports.ai_status says whether a report has a completed AI analysis,
--      but clients could write any value. The app inserts the report with
--      ai_status 'completed' BEFORE its ai_analyses row exists
--      (lib/features/create_post/models/post_draft.dart, then
--      create_post_service.dart inserts the analysis), and a reporter could
--      later set 'completed' on a report with no analysis. The database now
--      derives ai_status from ai_analyses and refuses writes that disagree.
--
-- Rules (for signed-in callers, admins included):
--   - Insert: 'completed' is stored as 'pending', because no analysis can
--     exist yet. Other values are stored as given ('unavailable' is what the
--     app writes for a report without an analysis).
--   - Update of ai_status: it must be 'completed' when the report has a
--     completed ai_analyses row, and must not be 'completed' when it has
--     none. Anything else raises FW409 ai_status_mismatch (PostgREST: HTTP
--     400, code in error.code). Updates that leave ai_status out of the
--     column list are not checked.
--   - Writes without a signed-in user (auth.uid() is null: the dashboard SQL
--     Editor, migrations, server jobs) are not checked or changed.
--
-- Sync from ai_analyses: after an analysis is inserted or deleted, or its
-- status or report_id changes, the report is set to 'completed' when it has
-- a completed analysis; otherwise a report that says 'completed' becomes
-- 'unavailable'. 'pending', 'unavailable' and 'failed' are otherwise left
-- alone. This runs for every caller, including the dashboard.
--
-- So the app's create-post flow ends as before: the report is saved as
-- 'pending', then its analysis insert turns it 'completed'. Clients no
-- longer need to write ai_status at all.
--
-- resubmit_report() (add_report_change_requests) is unchanged and still
-- works: when the photos changed it deletes the analyses (the sync sets
-- 'unavailable' if the report said 'completed'), then sets 'unavailable'
-- itself, which passes the check.
--
-- Data: checked on the hosted project on 2026-11-12: 0 reports disagree
-- with their analyses, so no rows are changed here.
--
-- New: guard_report_ai_status() + trigger guard_report_ai_status_trigger on
--   reports; sync_report_ai_status() + trigger ai_analyses_sync_report_ai_status
--   on ai_analyses.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- reports: check (or, on insert, correct) ai_status
-- ---------------------------------------------------------------------------

-- Security definer so the analysis check sees every ai_analyses row, not
-- only the ones the caller may read.
create or replace function public.guard_report_ai_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_completed boolean;
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- No analysis can reference a report that doesn't exist yet. The
    -- analysis insert sets 'completed' (sync_report_ai_status).
    if new.ai_status = 'completed' then
      new.ai_status := 'pending';
    end if;
    return new;
  end if;

  v_has_completed := exists (
    select 1 from public.ai_analyses a
    where a.report_id = new.id
      and a.status = 'completed'
  );

  if (new.ai_status = 'completed') <> v_has_completed then
    raise exception 'ai_status_mismatch'
      using errcode = 'FW409', detail = new.id::text;
  end if;

  return new;
end;
$$;

revoke execute on function public.guard_report_ai_status() from public, anon, authenticated;

drop trigger if exists guard_report_ai_status_trigger on public.reports;
create trigger guard_report_ai_status_trigger
  before insert or update of ai_status on public.reports
  for each row execute function public.guard_report_ai_status();


-- ---------------------------------------------------------------------------
-- ai_analyses: keep the report's ai_status in step
-- ---------------------------------------------------------------------------

-- Security definer: the report may not be updatable by the caller (an
-- analysis insert is the owner's, an analysis update is an admin's).
create or replace function public.sync_report_ai_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report_id uuid;
begin
  -- An update can move an analysis to another report: sync both.
  for v_report_id in
    select distinct x.id
    from unnest(case tg_op
                  when 'INSERT' then array[new.report_id]
                  when 'DELETE' then array[old.report_id]
                  else array[old.report_id, new.report_id]
                end) as x(id)
  loop
    if exists (
      select 1 from public.ai_analyses a
      where a.report_id = v_report_id
        and a.status = 'completed'
    ) then
      update public.reports
      set ai_status = 'completed'
      where id = v_report_id
        and ai_status <> 'completed';
    else
      update public.reports
      set ai_status = 'unavailable'
      where id = v_report_id
        and ai_status = 'completed';
    end if;
  end loop;

  return null;
end;
$$;

revoke execute on function public.sync_report_ai_status() from public, anon, authenticated;

drop trigger if exists ai_analyses_sync_report_ai_status on public.ai_analyses;
create trigger ai_analyses_sync_report_ai_status
  after insert or delete or update of status, report_id on public.ai_analyses
  for each row execute function public.sync_report_ai_status();


comment on column public.reports.ai_status is
  'Whether the report has a completed AI analysis. Set by the database from '
  'ai_analyses (sync_report_ai_status); clients should not write it. A '
  'signed-in insert of completed is stored as pending, and a signed-in '
  'update that disagrees with ai_analyses raises FW409 ai_status_mismatch.';
