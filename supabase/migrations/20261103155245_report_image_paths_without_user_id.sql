-- =============================================================================
-- Migration: report_image_paths_without_user_id
-- Why: Three problems with report photos:
--   1. Paths were {user_id}/{report_id}/{filename}, so anyone who can see a
--      photo also learns who posted it, while community_reports() is meant
--      to keep reporters anonymous.
--   2. The "approved report" part of the photo select policies looked up
--      public.reports, whose own RLS only lets owners and admins read it,
--      so other users could never see approved photos (the intent of
--      restrict_location_and_images was owner, admin, or approved).
--   3. Owners could add, replace or delete photos after a report was
--      reviewed, although the report itself is only editable while pending.
--
-- Changes:
--   - New path convention: {report_id}/{filename}. Policies read the report
--     id from the path with report_id_from_image_path(); other layouts get
--     no owner or community access (admins still see everything).
--   - can_view_report_media() (security definer) decides who may see a
--     report's photos: admins, the owner, or anyone signed in once the
--     report is approved. Used for storage objects and report_images rows.
--     ai_analyses visibility is unchanged.
--   - can_edit_report_media(): only the owner, only while pending. Used for
--     uploads, replacements and deletes, in storage and report_images.
--   - report_images rows must point at a path inside their own report.
--
-- ⚠️ Existing files in the old layout become admin-only. On the hosted
-- project there was one (test data, 2026-11-03), to be deleted by hand.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Report id from a {report_id}/{filename} path; null for any other shape.
create or replace function public.report_id_from_image_path(p_path text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when p_path ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[^/]+$'
      then split_part(p_path, '/', 1)::uuid
  end;
$$;

-- Security definer so the approved check isn't hidden by reports' own RLS.
-- Only answers yes/no; it never returns report data.
create or replace function public.can_view_report_media(p_report_id uuid)
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

-- Owner only, and only while the report is pending (same rule as editing
-- the report itself). Runs as the caller; owners can read their reports.
create or replace function public.can_edit_report_media(p_report_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.user_id = (select auth.uid())
      and r.status = 'pending'
  );
$$;

revoke execute on function public.report_id_from_image_path(text) from public, anon;
grant  execute on function public.report_id_from_image_path(text) to authenticated;
revoke execute on function public.can_view_report_media(uuid) from public, anon;
grant  execute on function public.can_view_report_media(uuid) to authenticated;
revoke execute on function public.can_edit_report_media(uuid) from public, anon;
grant  execute on function public.can_edit_report_media(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- Storage: report-images
-- ---------------------------------------------------------------------------

drop policy if exists "report_images_storage_select" on storage.objects;
create policy "report_images_storage_select"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'report-images'
    and public.can_view_report_media(public.report_id_from_image_path(name))
  );

drop policy if exists "report_images_storage_insert" on storage.objects;
create policy "report_images_storage_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'report-images'
    and public.can_edit_report_media(public.report_id_from_image_path(name))
  );

drop policy if exists "report_images_storage_update" on storage.objects;
create policy "report_images_storage_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'report-images'
    and public.can_edit_report_media(public.report_id_from_image_path(name))
  )
  with check (
    bucket_id = 'report-images'
    and public.can_edit_report_media(public.report_id_from_image_path(name))
  );

drop policy if exists "report_images_storage_delete" on storage.objects;
create policy "report_images_storage_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'report-images'
    and public.can_edit_report_media(public.report_id_from_image_path(name))
  );


-- ---------------------------------------------------------------------------
-- report_images rows
-- ---------------------------------------------------------------------------

comment on column public.report_images.storage_path is
  'Path inside the private report-images bucket: {report_id}/{filename}. '
  'Must start with this row''s report_id (enforced by the insert/update policies).';

drop policy if exists "report_images_select_owner_admin_approved" on public.report_images;
create policy "report_images_select_visible"
  on public.report_images
  for select
  to authenticated
  using (public.can_view_report_media(report_id));

drop policy if exists "report_images_insert_own" on public.report_images;
create policy "report_images_insert_own_pending"
  on public.report_images
  for insert
  to authenticated
  with check (
    public.can_edit_report_media(report_id)
    and public.report_id_from_image_path(storage_path) = report_id
  );

drop policy if exists "report_images_update_own" on public.report_images;
create policy "report_images_update_own_pending"
  on public.report_images
  for update
  to authenticated
  using (public.can_edit_report_media(report_id))
  with check (
    public.can_edit_report_media(report_id)
    and public.report_id_from_image_path(storage_path) = report_id
  );

drop policy if exists "report_images_delete_own" on public.report_images;
create policy "report_images_delete_own_pending"
  on public.report_images
  for delete
  to authenticated
  using (public.can_edit_report_media(report_id));
