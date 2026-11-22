-- =============================================================================
-- Migration: limit_report_photos_to_three
-- Why: The app now lets a post have up to 3 photos (the cover from FaunaLens
--   plus up to 2 more). Nothing in the database limited how many photos one
--   report could have, so a changed or older app could attach any number.
--
-- Changes:
--   - enforce_report_image_limit() + trigger report_images_limit_per_report:
--     refuses a new report_images row (or a row moved to another report) when
--     that report already has 3 photos.
--   - Two uploads for the same report at the same moment are handled one after
--     the other (a per-report lock held until the end of each insert), so both
--     cannot slip in as the 3rd photo.
--
-- Not changed: existing reports, storage policies, community_feed(),
--   community_reports() and the admin RPCs. Photos are still ordered by
--   created_at, id, and the app uploads the cover first.
-- Error: SQLSTATE 23514 (check_violation), message "A report can have at most
--   3 photos."
-- =============================================================================

create or replace function public.enforce_report_image_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- One insert per report at a time, so the count below stays correct.
  perform pg_advisory_xact_lock(
    hashtextextended('report_images:' || new.report_id::text, 0)
  );

  -- Security definer: counts every photo of the report, whatever RLS lets the
  -- caller see.
  if (
    select count(*)
    from public.report_images ri
    where ri.report_id = new.report_id
      and ri.id is distinct from new.id
  ) >= 3 then
    raise exception 'A report can have at most 3 photos.'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.enforce_report_image_limit() is
  'Trigger function: a report can have at most 3 report_images rows.';

-- Only the trigger runs it (triggers don't need these grants to fire).
revoke all on function public.enforce_report_image_limit()
  from public, anon, authenticated;

drop trigger if exists report_images_limit_per_report on public.report_images;
create trigger report_images_limit_per_report
  before insert or update of report_id on public.report_images
  for each row
  execute function public.enforce_report_image_limit();
