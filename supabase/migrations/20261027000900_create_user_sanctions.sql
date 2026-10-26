-- =============================================================================
-- Migration: create_user_sanctions
-- Why: Suspended users can still sign in (to see why) but cannot create
--      reports, comments, or community responses. Admin-only writes.
--      Users can read their own sanctions.
--
-- BEHAVIOUR CHANGE: adds suspension checks to insert policies on reports,
--   report_comments, and community_responses.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- user_sanctions table
-- ---------------------------------------------------------------------------

create table if not exists public.user_sanctions (
  id          uuid primary key default gen_random_uuid(),

  user_id     uuid not null references auth.users (id) on delete cascade,

  reason      text not null,

  created_by  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),

  -- null = indefinite (until manually lifted)
  ends_at     timestamptz,

  -- Set when an admin lifts the sanction early.
  lifted_at   timestamptz
);

comment on table public.user_sanctions is
  'User suspensions. A user with an active sanction (not lifted, not expired) '
  'can sign in but cannot create reports, comments, or community responses. '
  'Admin-only writes; users can read their own sanctions.';

create index if not exists user_sanctions_user_id_idx
  on public.user_sanctions (user_id);

-- Partial index for active sanctions (efficient lookup).
create index if not exists user_sanctions_active_idx
  on public.user_sanctions (user_id)
  where lifted_at is null;


-- ---------------------------------------------------------------------------
-- RLS — user_sanctions
-- ---------------------------------------------------------------------------

alter table public.user_sanctions enable row level security;

-- Users can read their own sanctions (to see why they're suspended).
create policy "user_sanctions_select_own"
  on public.user_sanctions
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Admins can read all sanctions.
create policy "user_sanctions_select_admin"
  on public.user_sanctions
  for select
  to authenticated
  using (public.is_admin());

-- Admin-only insert.
create policy "user_sanctions_insert_admin"
  on public.user_sanctions
  for insert
  to authenticated
  with check (public.is_admin());

-- Admin-only update (e.g. to set lifted_at).
create policy "user_sanctions_update_admin"
  on public.user_sanctions
  for update
  to authenticated
  using (public.is_admin());

-- Admin-only delete (rare — prefer lifting via lifted_at).
create policy "user_sanctions_delete_admin"
  on public.user_sanctions
  for delete
  to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------------
-- is_suspended(uid) helper
-- ---------------------------------------------------------------------------

create or replace function public.is_suspended(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_sanctions
    where user_id = p_uid
      and lifted_at is null
      and (ends_at is null or ends_at > now())
  );
$$;


-- ---------------------------------------------------------------------------
-- Add suspension check to insert policies
-- ---------------------------------------------------------------------------

-- reports: replace reports_insert_own to add suspension check.
drop policy if exists "reports_insert_own" on public.reports;
create policy "reports_insert_own"
  on public.reports
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and status = 'pending'
    and not public.is_suspended((select auth.uid()))
  );

-- report_comments: replace report_comments_insert_own to add suspension check.
drop policy if exists "report_comments_insert_own" on public.report_comments;
create policy "report_comments_insert_own"
  on public.report_comments
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.reports r
      where r.id = report_comments.report_id
        and r.status = 'approved'
    )
    and not public.is_suspended((select auth.uid()))
  );

-- community_responses: replace community_responses_insert_own to add suspension check.
drop policy if exists "community_responses_insert_own" on public.community_responses;
create policy "community_responses_insert_own"
  on public.community_responses
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and not public.is_suspended((select auth.uid()))
  );
