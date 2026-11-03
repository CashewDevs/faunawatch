-- =============================================================================
-- Migration: comments_cannot_move_between_reports
-- Why: The report_comments_update_own policy only checks that the caller
--      owns the comment, so an owner could change report_id and move the
--      comment onto another report, including one that isn't approved
--      (the insert policy only allows comments on approved reports).
--      A guard trigger now rejects any change to report_id; editing the
--      body is unaffected.
-- =============================================================================

create or replace function public.guard_report_comments_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.report_id is distinct from old.report_id then
    raise exception 'A comment cannot be moved to another report';
  end if;
  return new;
end;
$$;

create trigger guard_report_comments_update_trigger
  before update on public.report_comments
  for each row execute function public.guard_report_comments_update();
