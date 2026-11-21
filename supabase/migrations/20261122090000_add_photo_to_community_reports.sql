-- =============================================================================
-- Migration: add_photo_to_community_reports
-- Why: The community map's pins show each post's own photo instead of the
--      shared logo pin. The map loads its pins from community_reports(), so it
--      needs the post's first photo.
--
-- New column: photo_path, the storage path (in the private report-images
--   bucket) of the report's first photo, oldest first, or null when it has
--   none. It uses exactly the same rule as community_feed()
--   (20261112100000): only paths in the {report_id}/{filename} layout, so the
--   map can show nothing the For You feed doesn't already show for the same
--   approved report. The app still needs a signed URL to read the file.
--
-- Nothing else changes: same parameters, columns (photo_path is added last),
-- rounded coordinates, approved-only rule and grants. The result columns
-- change, so the function is dropped and recreated (create or replace cannot
-- change result columns). Apply by hand in the SQL Editor; the app keeps its
-- logo pins until this is applied.
-- =============================================================================

drop function if exists public.community_reports(
  double precision, double precision, double precision, double precision
);

create function public.community_reports(
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
  created_at        timestamptz,
  photo_path        text
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
    r.created_at,
    (
      select ri.storage_path
      from public.report_images ri
      where ri.report_id = r.id
        -- Only the {report_id}/{filename} layout can be shown to the community.
        and public.report_id_from_image_path(ri.storage_path) = r.id
      order by ri.created_at, ri.id
      limit 1
    ) as photo_path
  from public.reports r
    left join public.ai_analyses a on a.report_id = r.id
      and a.status = 'completed'
  where r.status = 'approved'
    -- Coarse pre-filter on the exact coordinates, widened by half a
    -- rounding step, so reports_location_idx can still be used. It only
    -- narrows the candidates; the rounded checks below decide the result.
    and r.latitude  between p_min_lat - 0.005 and p_max_lat + 0.005
    and r.longitude between p_min_lng - 0.005 and p_max_lng + 0.005
    and round(r.latitude::numeric, 2)::double precision
          between p_min_lat and p_max_lat
    and round(r.longitude::numeric, 2)::double precision
          between p_min_lng and p_max_lng;
$$;

revoke execute on function public.community_reports(double precision, double precision, double precision, double precision) from public, anon;
grant  execute on function public.community_reports(double precision, double precision, double precision, double precision) to authenticated;
