-- =============================================================================
-- Migration: hide_admin_identity_from_users
-- Why: Two owner select policies let users read the id of the admin who acted
--      on them, and with profiles readable, that admin's name:
--
--   - report_reviews_select_own_report (create_moderation): a reporter could
--     select every column of the reviews on their own reports, including
--     decided_by, so they learned who approved, declined or took down their
--     post.
--   - user_sanctions_select_own (create_user_sanctions): a suspended user
--     could select their own sanctions, including created_by, so they
--     learned who suspended them.
--
-- Users must never learn which admin acted (the same rule as
-- report_change_requests). A row policy can't hide one column, and column
-- grants would hide these columns from admins too (they use the same
-- database role), so:
--
--   report_reviews
--   - The owner select policy is dropped. Reporters read their decisions
--     through my_report_reviews(): report_id, decision, decline_reason and
--     decided_at only.
--   - report_reviews_insert_admin is dropped too. Decisions are written only
--     by admin_decide_report() and admin_take_down_report() (security
--     definer, unaffected), which change the post's status in the same
--     transaction; a direct insert could record a decision that never
--     happened.
--
--   user_sanctions
--   - The owner select policy is dropped. Users read their own sanctions
--     through my_sanctions(): id, reason, created_at, ends_at, lifted_at and
--     is_active only. Writes already go only through admin_suspend_user()
--     and admin_reactivate_user() (no client write policies since
--     add_admin_suspend_and_reactivate_user).
--
--   Both tables: clients are granted select only (anon nothing), like
--   report_change_requests. Admins still read every row through the
--   remaining admin select policies, so the admin site (analytics, reviewer
--   names, suspension counts) is unchanged. is_suspended(),
--   notify_report_status_change() and the admin user functions read these
--   tables as security definer functions and are unaffected.
--
-- No app code reads either table today. Existing rows untouched.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_reviews: admins read; only the moderation functions write
-- ---------------------------------------------------------------------------

drop policy if exists "report_reviews_select_own_report" on public.report_reviews;
drop policy if exists "report_reviews_insert_admin" on public.report_reviews;

revoke all on public.report_reviews from anon, authenticated;
grant select on public.report_reviews to authenticated;


-- ---------------------------------------------------------------------------
-- my_report_reviews(): the reporter's decisions, without the admin
-- ---------------------------------------------------------------------------

-- The caller's own reports only. p_report_id null = all of them.
-- Oldest decision first per report (a take-down follows the approval).
create or replace function public.my_report_reviews(p_report_id uuid default null)
returns table (
  report_id      uuid,
  decision       public.report_status,
  decline_reason public.decline_reason,
  decided_at     timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    rr.report_id,
    rr.decision,
    rr.decline_reason,
    rr.decided_at
  from public.report_reviews rr
    join public.reports r on r.id = rr.report_id
  where r.user_id = (select auth.uid())
    and (p_report_id is null or rr.report_id = p_report_id)
  order by rr.report_id, rr.decided_at, rr.id;
$$;

revoke execute on function public.my_report_reviews(uuid) from public, anon;
grant  execute on function public.my_report_reviews(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- user_sanctions: admins read; only the admin functions write
-- ---------------------------------------------------------------------------

drop policy if exists "user_sanctions_select_own" on public.user_sanctions;

revoke all on public.user_sanctions from anon, authenticated;
grant select on public.user_sanctions to authenticated;


-- ---------------------------------------------------------------------------
-- my_sanctions(): the caller's own suspensions, without the admin
-- ---------------------------------------------------------------------------

-- All of the caller's sanctions, newest first, so the app can explain a
-- current suspension and show past ones. is_active uses the same rule as
-- is_suspended(): not lifted and not yet ended.
create or replace function public.my_sanctions()
returns table (
  id         uuid,
  reason     text,
  created_at timestamptz,
  ends_at    timestamptz,
  lifted_at  timestamptz,
  is_active  boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    s.id,
    s.reason,
    s.created_at,
    s.ends_at,
    s.lifted_at,
    (s.lifted_at is null and (s.ends_at is null or s.ends_at > now())) as is_active
  from public.user_sanctions s
  where s.user_id = (select auth.uid())
  order by s.created_at desc, s.id;
$$;

revoke execute on function public.my_sanctions() from public, anon;
grant  execute on function public.my_sanctions() to authenticated;
