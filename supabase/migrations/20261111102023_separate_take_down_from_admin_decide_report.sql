-- =============================================================================
-- Migration: separate_take_down_from_admin_decide_report
-- Why: make_report_decisions_final_except_take_down let admin_decide_report()
--      decline an approved report, as the way to take a post down. A browser
--      test showed the flaw: an admin whose page still shows a post as
--      pending presses Decline after another admin approved it, and the
--      call silently becomes a take-down instead of being rejected as
--      "already decided". A take-down must be something an admin chose.
--
-- Now:
--   admin_decide_report(ids, decision, reason)
--     pending -> approved | declined only. Anything else raises
--     report_already_decided (FW409). Otherwise unchanged.
--   admin_take_down_report(report_id, reason)   (new)
--     approved -> declined only, one report at a time, reason required.
--     A report that isn't approved raises report_not_approved (FW409);
--     a missing one raises report_not_found (FW404).
--
-- Both record a report_reviews row and change the status together, through
-- the same faunawatch.deciding_report flag guard_report_status() checks.
-- Non-admins get insufficient_privilege (42501). Existing rows untouched.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- admin_decide_report(): pending reports only
-- ---------------------------------------------------------------------------

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

    if v_status <> 'pending' then
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


-- ---------------------------------------------------------------------------
-- admin_take_down_report(): decline one approved report
-- ---------------------------------------------------------------------------

create or replace function public.admin_take_down_report(
  p_report_id      uuid,
  p_decline_reason public.decline_reason
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.report_status;
begin
  if not public.is_admin() then
    raise exception 'Only admins can take down reports'
      using errcode = 'insufficient_privilege';
  end if;

  if p_report_id is null then
    raise exception 'Choose a report';
  end if;

  if p_decline_reason is null then
    raise exception 'Decline reason is required when taking down a report';
  end if;

  select r.status into v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found then
    raise exception 'report_not_found'
      using errcode = 'FW404', detail = p_report_id::text;
  end if;

  if v_status <> 'approved' then
    raise exception 'report_not_approved'
      using errcode = 'FW409', detail = p_report_id::text;
  end if;

  perform set_config('faunawatch.deciding_report', 'on', true);

  insert into public.report_reviews (report_id, decision, decline_reason, decided_by)
  values (p_report_id, 'declined', p_decline_reason, (select auth.uid()));

  update public.reports
  set status = 'declined'
  where id = p_report_id;

  perform set_config('faunawatch.deciding_report', '', true);
end;
$$;

revoke execute on function public.admin_take_down_report(uuid, public.decline_reason) from public, anon;
grant  execute on function public.admin_take_down_report(uuid, public.decline_reason) to authenticated;
