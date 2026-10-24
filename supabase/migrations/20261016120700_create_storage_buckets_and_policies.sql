-- =============================================================================
-- Migration: create_storage_buckets_and_policies
-- Why: Storage buckets and their access policies must be created via migrations,
--      not through the Supabase Dashboard (SUPABASE_MIGRATIONS.md). Both
--      buckets are private by default. Object access is tied to the owning
--      user via path-prefix conventions.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Bucket: report-images (private)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'report-images',
  'report-images',
  false,                  -- private: no public URLs
  10485760,               -- 10 MB per file (adjust if SRS specifies otherwise)
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;

-- Object path convention: {user_id}/{report_id}/{filename}
-- This lets policies scope access to the owning user without a DB join.


-- Storage policies: report-images
-- Supabase storage policies use storage.objects with a bucket_id check.

-- SELECT: authenticated users can download images they are allowed to see.
-- Mirrors report visibility: for now, any authenticated user.
-- OPEN QUESTION: narrow once report visibility model is decided
-- (same TODO as reports_select_authenticated in migration 4).
drop policy if exists "report_images_storage_select" on storage.objects;
create policy "report_images_storage_select"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'report-images'
    -- TODO(open question): should this be limited to users who can access the
    --   parent report? Tighten this once the report visibility model is confirmed.
  );

-- INSERT: authenticated users can upload to their own path prefix.
drop policy if exists "report_images_storage_insert" on storage.objects;
create policy "report_images_storage_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    -- The first path segment must equal the uploading user's UID.
    -- Full path: {auth.uid()}/{report_id}/{filename}
  );

-- UPDATE: users can update (replace) only their own objects.
drop policy if exists "report_images_storage_update" on storage.objects;
create policy "report_images_storage_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: users can delete only their own objects.
drop policy if exists "report_images_storage_delete" on storage.objects;
create policy "report_images_storage_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'report-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ---------------------------------------------------------------------------
-- Bucket: avatars (private — default; see OPEN QUESTION)
-- ---------------------------------------------------------------------------

-- OPEN QUESTION: the SRS does not specify whether avatars should be public or
-- private. Defaulting to private. If avatars should be publicly visible (e.g.
-- visible on the community map without authentication), change public to true
-- and remove the select policy below in favour of a public bucket URL.
-- TODO(open question): should the avatars bucket be public or private?

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,                  -- private by default; see OPEN QUESTION above
  2097152,                -- 2 MB per avatar
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

-- Object path convention: {user_id}/{filename}

-- SELECT: authenticated users can read any avatar (community-visible display names)
drop policy if exists "avatars_storage_select" on storage.objects;
create policy "avatars_storage_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'avatars');

-- INSERT: users can only upload to their own path prefix
drop policy if exists "avatars_storage_insert" on storage.objects;
create policy "avatars_storage_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE: users can only replace their own avatar
drop policy if exists "avatars_storage_update" on storage.objects;
create policy "avatars_storage_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: users can only delete their own avatar
drop policy if exists "avatars_storage_delete" on storage.objects;
create policy "avatars_storage_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
