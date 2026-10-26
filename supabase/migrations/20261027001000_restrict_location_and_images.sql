-- =============================================================================
-- Migration: restrict_location_and_images
-- Why: This migration changes who can see what. It replaces the broad
--      "authenticated users see all reports" policy with owner-or-admin
--      only, and introduces the community_reports RPC that returns approved
--      reports with coordinates snapped to ~1 km (2 decimal places).
--
-- ⚠️ BEHAVIOUR CHANGE: reports_select_authenticated is replaced.
--   Other users can no longer directly query the reports table.
--   Community access goes through the community_reports() RPC.
--
-- ⚠️ BEHAVIOUR CHANGE: report_images and ai_analyses select policies
--   are tightened to owner/admin/approved.
--
-- ⚠️ BEHAVIOUR CHANGE: report-images storage select policy is tightened.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- reports: replace select policy → owner or admin only
-- ---------------------------------------------------------------------------

drop policy if exists "reports_select_authenticated" on public.reports;

create policy "reports_select_owner_admin"
  on public.reports
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.is_admin()
  );


-- ---------------------------------------------------------------------------
-- community_reports() RPC: approved reports with ~1 km precision
-- ---------------------------------------------------------------------------

-- Returns approved reports within a bounding box, with coordinates rounded
-- to 2 decimal places (~1.1 km at the equator). Does NOT include user_id,
-- profile name, or avatar (OQ 8 resolution: stay anonymous).

create or replace function public.community_reports(
  p_min_lat double precision,
  p_min_lng double precision,
  p_max_lat double precision,
  p_max_lng double precision
)
returns table (
  id                uuid,
  category          public.report_category,
  description       text,
  latitude          double precision,
  longitude         double precision,
  severity          public.severity_level,
  ai_status         public.ai_status,
  possible_species  jsonb,
  species_origin    public.species_origin,
  possible_invasive boolean,
  incident_summary  text,
  created_at        timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.category,
    r.description,
    round(r.latitude::numeric, 2)::double precision  as latitude,
    round(r.longitude::numeric, 2)::double precision as longitude,
    a.severity,
    r.ai_status,
    a.possible_species,
    a.species_origin,
    a.possible_invasive,
    a.incident_summary,
    r.created_at
  from public.reports r
    left join public.ai_analyses a on a.report_id = r.id
      and a.status = 'completed'
  where r.status = 'approved'
    and r.latitude  between p_min_lat and p_max_lat
    and r.longitude between p_min_lng and p_max_lng;
$$;

revoke execute on function public.community_reports(double precision, double precision, double precision, double precision) from public, anon;
grant  execute on function public.community_reports(double precision, double precision, double precision, double precision) to authenticated;


-- ---------------------------------------------------------------------------
-- report_images: tighten select → owner, admin, or approved report
-- ---------------------------------------------------------------------------

drop policy if exists "report_images_select_authenticated" on public.report_images;

create policy "report_images_select_owner_admin_approved"
  on public.report_images
  for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = report_images.report_id
        and (
          r.user_id = (select auth.uid())
          or public.is_admin()
          or r.status = 'approved'
        )
    )
  );


-- ---------------------------------------------------------------------------
-- ai_analyses: tighten select → owner, admin, or approved report
-- ---------------------------------------------------------------------------

drop policy if exists "ai_analyses_select_authenticated" on public.ai_analyses;

create policy "ai_analyses_select_owner_admin_approved"
  on public.ai_analyses
  for select
  to authenticated
  using (
    exists (
      select 1 from public.reports r
      where r.id = ai_analyses.report_id
        and (
          r.user_id = (select auth.uid())
          or public.is_admin()
          or r.status = 'approved'
        )
    )
  );

-- Drop the admin-specific select added in migration 7 since it's now
-- covered by the broader policy above.
drop policy if exists "ai_analyses_select_admin" on public.ai_analyses;


-- ---------------------------------------------------------------------------
-- Storage: report-images — tighten select
-- ---------------------------------------------------------------------------

-- Path convention: {user_id}/{report_id}/{filename}
-- Allow:
--   1. Owner (path segment 1 = auth.uid())
--   2. Admin
--   3. Report in path segment 2 is approved

drop policy if exists "report_images_storage_select" on storage.objects;

create policy "report_images_storage_select"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'report-images'
    and (
      -- Owner: first path segment is the user's UID
      (storage.foldername(name))[1] = (select auth.uid())::text
      -- Admin
      or public.is_admin()
      -- Approved report: second path segment is the report_id
      or exists (
        select 1 from public.reports r
        where r.id = ((storage.foldername(name))[2])::uuid
          and r.status = 'approved'
      )
    )
  );


-- ---------------------------------------------------------------------------
-- Avatars: no change needed
-- ---------------------------------------------------------------------------

-- preset:<name> values are not storage paths; the avatars bucket policy
-- is unchanged. Uploaded avatars continue to use {user_id}/{filename}.
