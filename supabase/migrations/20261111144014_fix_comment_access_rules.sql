-- =============================================================================
-- Migration: fix_comment_access_rules
-- Why: Two bugs in the report_comments policies.
--
--   1. Reads leaked. report_comments_select_visible only checked
--      is_comment_visible(), so any signed-in user could read every comment
--      that hadn't been removed, on any report: pending, declined, or
--      approved and later taken down. create_comments said the parent report
--      check was "deferred to migration 10" (restrict_location_and_images),
--      but that migration never changed this policy, so it was never added.
--
--   2. Only report owners and admins could comment.
--      report_comments_insert_own checked "report is approved" with a plain
--      subquery on reports, whose own RLS only lets the owner and admins read
--      a report. For everyone else the subquery found nothing, so their
--      insert was refused.
--
-- Rules after this migration (all for signed-in users):
--   Read:   a comment that isn't removed (admins also see removed ones), on a
--           report the reader may see (admin, report owner, or approved),
--           or the reader's own comment on any report. So a take-down hides
--           the post's comments from others, but the author can still see
--           and delete their own.
--   Insert: own comment, on an approved report, not suspended.
--   Update: own comment, only while the report is approved (also for the
--           report owner), not suspended. Moving a comment to another
--           report is still refused by guard_report_comments_update().
--   Delete: own comment, always. A removed comment can't be read by its
--           author, so it can't be deleted either and its moderation record
--           stays. Suspended users can still delete their own comments.
--
-- New helpers, both security definer so reports' RLS doesn't hide the
-- report, both answering yes/no only:
--   can_view_report_comments(report_id): admin, report owner, or approved.
--     Same rule as can_view_report_media() today, but kept separate so a
--     later change to who may see a report's photos doesn't silently
--     change who may read its comments.
--   is_report_approved(report_id): the report exists and is approved. Used
--     for insert and update, where being admin or owner doesn't matter.
--
-- Existing rows untouched.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.can_view_report_comments(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or exists (
      select 1 from public.reports r
      where r.id = p_report_id
        and (
          r.user_id = (select auth.uid())
          or r.status = 'approved'
        )
    );
$$;

create or replace function public.is_report_approved(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.status = 'approved'
  );
$$;

revoke execute on function public.can_view_report_comments(uuid) from public, anon;
grant  execute on function public.can_view_report_comments(uuid) to authenticated;
revoke execute on function public.is_report_approved(uuid) from public, anon;
grant  execute on function public.is_report_approved(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- report_comments policies
-- ---------------------------------------------------------------------------

drop policy if exists "report_comments_select_visible" on public.report_comments;
create policy "report_comments_select_visible"
  on public.report_comments
  for select
  to authenticated
  using (
    public.is_comment_visible(id)
    and (
      public.can_view_report_comments(report_id)
      or (select auth.uid()) = user_id
    )
  );

drop policy if exists "report_comments_insert_own" on public.report_comments;
create policy "report_comments_insert_own"
  on public.report_comments
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_report_approved(report_id)
    and not public.is_suspended((select auth.uid()))
  );

drop policy if exists "report_comments_update_own" on public.report_comments;
create policy "report_comments_update_own"
  on public.report_comments
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    and public.is_report_approved(report_id)
    and not public.is_suspended((select auth.uid()))
  )
  with check (
    (select auth.uid()) = user_id
    and public.is_report_approved(report_id)
    and not public.is_suspended((select auth.uid()))
  );

drop policy if exists "report_comments_delete_own" on public.report_comments;
create policy "report_comments_delete_own"
  on public.report_comments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
