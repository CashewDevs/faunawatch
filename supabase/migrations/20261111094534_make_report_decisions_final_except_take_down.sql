-- =============================================================================
-- Migration: make_report_decisions_final_except_take_down
-- Why: admin_decide_report() accepted any report, so a report that was
--      already decided could be decided again: an admin with a stale tab, or
--      two admins at once, could flip a post and add another report_reviews
--      row. The team decided (2026-11-06, 2026-11-11) that a decision is
--      final, with one exception: an approved post can be taken down, which
--      declines it with a reason. That hides it from the community map, its
--      photos and its comments, which all require status = 'approved'.
--
-- Allowed now:
--   pending  -> approved | declined
--   approved -> declined   (take down)
-- Everything else raises 'report_already_decided' (SQLSTATE FW409) and
-- changes nothing. A declined post stays declined.
--
-- Other changes to the function:
--   - A batch is all or nothing (as before): one undecidable or missing report
--     rejects the whole call. Missing reports now raise 'report_not_found'
--     (SQLSTATE FW404) instead of a foreign key error.
--   - Repeated ids in p_report_ids are decided once, not once per copy.
--   - A null or empty p_report_ids raises instead of failing inside the loop.
--   - Reports are locked in id order before checking, so two admins deciding
--     the same post wait for each other and the second one is rejected.
--   - Non-admins get insufficient_privilege (42501, HTTP 403 in PostgREST),
--     like the other admin RPCs (see raise_in_admin_rpcs_for_non_admins).
--
-- Same signature and return type, so the grants are unchanged; they are
-- restated below to be explicit. Existing rows are not touched.
-- =============================================================================


create or replace function public.admin_decide_report(
  p_report_ids     uuid[],
  p_decision       public.report_status,
  p_decline_reason public.decline_reason default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_ids    uuid[];
  v_rid    uuid;
  v_status public.report_status;
begin
  if not public.is_admin() then
    raise exception 'Only admins can decide reports'
      using errcode = 'insufficient_privilege';
  end if;

  if p_decision is null or p_decision not in ('approved', 'declined') then
    raise exception 'Decision must be approved or declined';
  end if;

  if p_decision = 'declined' and p_decline_reason is null then
    raise exception 'Decline reason is required when declining a report';
  end if;

  if p_decision = 'approved' and p_decline_reason is not null then
    raise exception 'Decline reason must be null when approving a report';
  end if;

  -- Each report once, in a fixed order so concurrent calls lock alike.
  select array_agg(distinct u.id order by u.id)
    into v_ids
    from unnest(p_report_ids) as u(id)
    where u.id is not null;

  if v_ids is null then
    raise exception 'Choose at least one report';
  end if;

  -- Lock and check every report before changing any of them.
  foreach v_rid in array v_ids loop
    select r.status into v_status
      from public.reports r
      where r.id = v_rid
      for update;

    if not found then
      raise exception 'report_not_found'
        using errcode = 'FW404', detail = v_rid::text;
    end if;

    if not (
      v_status = 'pending'
      or (v_status = 'approved' and p_decision = 'declined')
    ) then
      raise exception 'report_already_decided'
        using errcode = 'FW409', detail = v_rid::text;
    end if;
  end loop;

  -- Let guard_report_status() accept the status updates below.
  perform set_config('faunawatch.deciding_report', 'on', true);

  foreach v_rid in array v_ids loop
    insert into public.report_reviews (report_id, decision, decline_reason, decided_by)
    values (v_rid, p_decision, p_decline_reason, v_uid);

    update public.reports
    set status = p_decision
    where id = v_rid;
  end loop;

  -- Clear the flag so later statements in the same transaction are guarded.
  perform set_config('faunawatch.deciding_report', '', true);
end;
$$;

revoke execute on function public.admin_decide_report(uuid[], public.report_status, public.decline_reason) from public, anon;
grant  execute on function public.admin_decide_report(uuid[], public.report_status, public.decline_reason) to authenticated;
