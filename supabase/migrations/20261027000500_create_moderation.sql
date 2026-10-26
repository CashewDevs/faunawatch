-- =============================================================================
-- Migration: create_moderation
-- Why: Full moderation workflow. Includes:
--   - Guard trigger so only admins can change report status
--   - Tightened insert/update policies on reports (status = 'pending')
--   - report_reviews table (one row per admin decision)
--   - admin_notes table (internal admin-only notes)
--   - admin_decide_report() RPC for bulk approve/decline
--
-- BEHAVIOUR CHANGE: reports_update_own now blocks edits to decided reports
--   (OQ 1 resolution — conservative option).
-- BEHAVIOUR CHANGE: reports_insert_own now enforces status = 'pending'.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Change default for reports.status
-- ---------------------------------------------------------------------------

-- 'submitted' was renamed to 'pending' in migration 4. Update the column
-- default to reference the new name explicitly.
alter table public.reports
  alter column status set default 'pending';


-- ---------------------------------------------------------------------------
-- Tighten reports_insert_own: new reports must have status = 'pending'
-- ---------------------------------------------------------------------------

drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
  on public.reports
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
  );


-- ---------------------------------------------------------------------------
-- Tighten reports_update_own: owners can only edit pending reports (OQ 1)
-- ---------------------------------------------------------------------------

drop policy if exists "reports_update_own" on public.reports;
create policy "reports_update_own"
  on public.reports
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    and status = 'pending'
  )
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
  );


-- ---------------------------------------------------------------------------
-- Admin update policy on reports (for status changes, etc.)
-- ---------------------------------------------------------------------------

create policy "reports_update_admin"
  on public.reports
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());


-- ---------------------------------------------------------------------------
-- Guard trigger: only admins can change report status
-- ---------------------------------------------------------------------------

create or replace function public.guard_report_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and not public.is_admin() then
    raise exception 'Only admins can change report status';
  end if;
  return new;
end;
$$;

create trigger guard_report_status_trigger
  before update on public.reports
  for each row execute function public.guard_report_status();


-- ---------------------------------------------------------------------------
-- report_reviews: one row per moderation decision
-- ---------------------------------------------------------------------------

create table if not exists public.report_reviews (
  id             uuid primary key default gen_random_uuid(),

  report_id      uuid not null references public.reports (id) on delete cascade,

  -- 'approved' or 'declined' — uses the report_status enum but only these
  -- two values are valid for a review decision.
  decision       public.report_status not null
                 check (decision in ('approved', 'declined')),

  -- Required when decision = 'declined'; null when approved.
  decline_reason public.decline_reason,

  decided_by     uuid not null references auth.users (id) on delete cascade,
  decided_at     timestamptz not null default now(),

  constraint report_reviews_decline_reason_required
    check (
      (decision = 'declined' and decline_reason is not null)
      or
      (decision = 'approved' and decline_reason is null)
    )
);

comment on table public.report_reviews is
  'Moderation decisions. One row per approve/decline action on a report. '
  'Multiple rows may exist if a report is re-reviewed.';

create index if not exists report_reviews_report_id_idx
  on public.report_reviews (report_id);

create index if not exists report_reviews_decided_by_idx
  on public.report_reviews (decided_by);

alter table public.report_reviews enable row level security;

-- Admins can read all reviews.
create policy "report_reviews_select_admin"
  on public.report_reviews
  for select
  to authenticated
  using (public.is_admin());

-- Report owners can read the decision on their own report (to see why it
-- was declined, for example).
create policy "report_reviews_select_own_report"
  on public.report_reviews
  for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_reviews.report_id
        and r.user_id = (select auth.uid())
    )
  );

-- Only admins can insert reviews (via the RPC below or directly).
create policy "report_reviews_insert_admin"
  on public.report_reviews
  for insert
  to authenticated
  with check (public.is_admin());


-- ---------------------------------------------------------------------------
-- admin_notes: internal notes on a report, admin-only
-- ---------------------------------------------------------------------------

create table if not exists public.admin_notes (
  id         uuid primary key default gen_random_uuid(),

  report_id  uuid not null references public.reports (id) on delete cascade,
  author_id  uuid not null references auth.users (id) on delete cascade,

  body       text not null,

  created_at timestamptz not null default now()
  -- No updated_at: admin notes are append-only. Edit by deleting + re-adding.
);

comment on table public.admin_notes is
  'Internal admin notes on a report. Never visible to report owners or '
  'regular users. Admin-only for all operations.';

create index if not exists admin_notes_report_id_idx
  on public.admin_notes (report_id);

alter table public.admin_notes enable row level security;

-- All operations: admin only.
create policy "admin_notes_select_admin"
  on public.admin_notes
  for select
  to authenticated
  using (public.is_admin());

create policy "admin_notes_insert_admin"
  on public.admin_notes
  for insert
  to authenticated
  with check (public.is_admin());

create policy "admin_notes_delete_admin"
  on public.admin_notes
  for delete
  to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------------
-- admin_decide_report() RPC: bulk approve/decline
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
end;
$$;

revoke execute on function public.admin_decide_report(uuid[], public.report_status, public.decline_reason) from public, anon;
grant  execute on function public.admin_decide_report(uuid[], public.report_status, public.decline_reason) to authenticated;
