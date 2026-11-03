-- =============================================================================
-- Migration: report_status_changes_only_via_admin_decide_report
-- Why: The reports_update_admin policy let admins change reports.status
--      with a plain UPDATE, which skips report_reviews, so the decision had
--      no audit row (who, when, decline reason). Status changes now only
--      go through admin_decide_report(), which writes the review row and
--      the status together.
--
-- How: admin_decide_report() sets a transaction-local flag
--      (faunawatch.deciding_report) around its UPDATE, and
--      guard_report_status() rejects a status change unless the flag is
--      set. Clients can't set it: PostgREST doesn't expose set_config().
--      The flag is cleared again before the function returns.
--
-- Admins can still update other report columns directly. Moving a report
-- back to 'pending' is no longer possible (admin_decide_report() only
-- accepts approved/declined); nothing uses that today.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- guard_report_status(): status changes only inside admin_decide_report()
-- ---------------------------------------------------------------------------

create or replace function public.guard_report_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if not public.is_admin() then
      raise exception 'Only admins can change report status';
    end if;
    if coalesce(current_setting('faunawatch.deciding_report', true), '') <> 'on' then
      raise exception 'Report status can only be changed through admin_decide_report()';
    end if;
  end if;
  return new;
end;
$$;


-- ---------------------------------------------------------------------------
-- admin_decide_report(): unchanged apart from setting and clearing the flag
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
  v_uid uuid;
  v_rid uuid;
begin
  -- Auth check
  v_uid := (select auth.uid());
  if not public.is_admin() then
    raise exception 'Only admins can decide reports';
  end if;

  -- Validate decision value
  if p_decision not in ('approved', 'declined') then
    raise exception 'Decision must be approved or declined';
  end if;

  -- Validate decline reason
  if p_decision = 'declined' and p_decline_reason is null then
    raise exception 'Decline reason is required when declining a report';
  end if;

  if p_decision = 'approved' and p_decline_reason is not null then
    raise exception 'Decline reason must be null when approving a report';
  end if;

  -- Let guard_report_status() accept the status updates below.
  perform set_config('faunawatch.deciding_report', 'on', true);

  -- Process each report
  foreach v_rid in array p_report_ids loop
    -- Insert the review record
    insert into public.report_reviews (report_id, decision, decline_reason, decided_by)
    values (v_rid, p_decision, p_decline_reason, v_uid);

    -- Update the report status
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
