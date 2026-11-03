-- =============================================================================
-- Migration: filter_community_reports_on_rounded_coordinates
-- Why: community_reports() returned coordinates rounded to 2 decimal places
--      (~1 km) but filtered the bounding box on the exact ones. Shrinking
--      the box until a report dropped out revealed its exact location.
--      The box now matches on the rounded coordinates, so which reports
--      come back depends only on what the caller can already see.
--
-- No signature or column change; grants are re-stated for clarity.
-- =============================================================================

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
