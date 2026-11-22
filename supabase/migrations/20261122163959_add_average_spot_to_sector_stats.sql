-- =============================================================================
-- Migration: add_average_spot_to_sector_stats
-- Why: The admin site's "Sighting Hotspots" map draws one circle per grid
--      cell (about 11 km wide). At the cell centre, a circle can sit kilometres
--      away from where the sightings actually are. Decided by the pilot on
--      2026-11-22: also return the exact average spot of each cell's reports,
--      and of each category's reports, so the circles sit where sightings
--      cluster.
--
-- ⚠️ PRIVACY TRADE-OFF (accepted by the pilot): the averages are exact, not
--   rounded. A cell still needs at least p_min_count reports to be returned,
--   but comparing two date ranges that differ by one report can reveal that
--   report's exact spot. Only admins can call this function.
--
-- What changes: three result columns are added after the existing four,
-- which are unchanged (same cells, counts, categories and min-count rule):
--   avg_lat, avg_lng  the average spot of every report in the cell.
--   category_spots    { "<category>": { "lat": ..., "lng": ... } } for every
--                     category in `categories`. A category uses the average
--                     of its own reports only when it has at least
--                     p_min_count of them in the cell; otherwise it gets the
--                     cell's average, so the spot of a category with one or
--                     two reports never leaves the database.
-- Cells are 0.1° wide, so a plain average of longitudes is safe (a cell never
-- spans the 180° line).
--
-- Postgres cannot add result columns with "create or replace", so the
-- function is dropped and created again with the same name, parameters,
-- admin check and grants. Nothing in the database depends on it, and the
-- mobile app does not call it.
--
-- Copied from the latest definition:
--   admin_sector_stats(): 20261103151619_raise_in_admin_rpcs_for_non_admins.sql
--
-- Apply by hand in the SQL Editor. The admin site works before and after it
-- is applied: it reads the new columns when present and falls back to the
-- cell centre otherwise.
-- =============================================================================

drop function if exists public.admin_sector_stats(timestamptz, timestamptz, double precision, integer);

create function public.admin_sector_stats(
  p_from_ts    timestamptz,
  p_to_ts      timestamptz,
  p_cell_size  double precision default 0.1,  -- ~11 km at the equator
  p_min_count  integer default 3
)
returns table (
  cell_lat       double precision,
  cell_lng       double precision,
  report_count   bigint,
  categories     jsonb,
  avg_lat        double precision,
  avg_lng        double precision,
  category_spots jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Only admins can read sector stats'
      using errcode = 'insufficient_privilege';
  end if;

  -- Three steps:
  --   1. cell_cats: count and coordinate sums per (cell, category)
  --   2. cell_totals: add each cell's total count and average spot to every
  --      row of that cell (window functions, so no join on float keys)
  --   3. Roll up to one row per cell, with the category counts and spots as
  --      JSONB, keeping only cells with at least p_min_count reports
  return query
  with cell_cats as (
    select
      floor(r.latitude  / p_cell_size) * p_cell_size + p_cell_size / 2 as c_lat,
      floor(r.longitude / p_cell_size) * p_cell_size + p_cell_size / 2 as c_lng,
      r.category::text    as cat,
      count(*)::bigint    as cnt,
      sum(r.latitude)     as sum_lat,
      sum(r.longitude)    as sum_lng
    from public.reports r
    where r.created_at between p_from_ts and p_to_ts
    group by c_lat, c_lng, r.category
  ),
  cell_totals as (
    select
      cc.*,
      sum(cc.cnt)     over cell                              as cell_cnt,
      sum(cc.sum_lat) over cell / sum(cc.cnt) over cell      as cell_mean_lat,
      sum(cc.sum_lng) over cell / sum(cc.cnt) over cell      as cell_mean_lng
    from cell_cats cc
    window cell as (partition by cc.c_lat, cc.c_lng)
  )
  select
    ct.c_lat                          as cell_lat,
    ct.c_lng                          as cell_lng,
    ct.cell_cnt::bigint               as report_count,
    jsonb_object_agg(ct.cat, ct.cnt)  as categories,
    ct.cell_mean_lat                  as avg_lat,
    ct.cell_mean_lng                  as avg_lng,
    jsonb_object_agg(
      ct.cat,
      case
        when ct.cnt >= p_min_count then jsonb_build_object(
          'lat', ct.sum_lat / ct.cnt,
          'lng', ct.sum_lng / ct.cnt
        )
        else jsonb_build_object(
          'lat', ct.cell_mean_lat,
          'lng', ct.cell_mean_lng
        )
      end
    )                                 as category_spots
  from cell_totals ct
  where ct.cell_cnt >= p_min_count
  group by ct.c_lat, ct.c_lng, ct.cell_cnt, ct.cell_mean_lat, ct.cell_mean_lng;
end;
$$;

revoke execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) from public, anon;
grant  execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) to authenticated;
