-- =============================================================================
-- Migration: round_community_locations_to_100m
-- Why: Pins on the community map and post locations in the For You feed were
--      rounded to 2 decimals (about 1 km), which was too coarse to be useful.
--      Decided by the pilot on 2026-11-22: round to 3 decimals instead, which
--      keeps every point within about 100 m of the real spot (the app draws a
--      100 m circle around each pin to show that it marks an area).
--
-- ⚠️ BEHAVIOUR CHANGE: public locations are about 10 times more precise.
--   Exact coordinates are still never returned to other users; only the owner
--   (through owner RLS) and admins can read them. place_name is unchanged and
--   still returned exactly as stored by community_feed() only.
--
-- What changes: in community_reports() and community_feed(), round(..., 2)
-- becomes round(..., 3), and community_reports()'s coarse pre-filter is
-- widened by half the new rounding step (0.0005) instead of the old one.
-- Nothing else changes: same parameters, result columns, approved-only rule,
-- ordering, paging and grants. The result columns are the same, so both are
-- replaced in place (create or replace), which keeps public_profile_gallery()
-- and other callers working.
--
-- Copied from the latest definitions:
--   community_reports(): 20261122090000_add_photo_to_community_reports.sql
--   community_feed():    20261121090000_add_ai_and_location_to_community_feed.sql
--
-- Apply by hand in the SQL Editor. The app works before and after it is
-- applied, in either order.
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
    round(r.latitude::numeric, 3)::double precision  as latitude,
    round(r.longitude::numeric, 3)::double precision as longitude,
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
    and r.latitude  between p_min_lat - 0.0005 and p_max_lat + 0.0005
    and r.longitude between p_min_lng - 0.0005 and p_max_lng + 0.0005
    and round(r.latitude::numeric, 3)::double precision
          between p_min_lat and p_max_lat
    and round(r.longitude::numeric, 3)::double precision
          between p_min_lng and p_max_lng;
$$;

revoke execute on function public.community_reports(double precision, double precision, double precision, double precision) from public, anon;
grant  execute on function public.community_reports(double precision, double precision, double precision, double precision) to authenticated;

create or replace function public.community_feed(
  p_before_at timestamptz default null,
  p_before_id uuid        default null,
  p_limit     integer     default 10,
  p_report_id uuid        default null
)
returns table (
  id                          uuid,
  category                    public.report_category,
  description                 text,
  user_species                text,
  severity                    public.severity_level,
  possible_species            jsonb,
  possible_invasive           boolean,
  visual_condition_assessment text,
  incident_summary            text,
  safety_recommendations      text,
  community_warning           text,
  invasive_match_name         text,
  place_name                  text,
  latitude                    double precision,
  longitude                   double precision,
  author_id                   uuid,
  author_name                 text,
  author_avatar_path          text,
  photo_paths                 text[],
  like_count                  integer,
  liked_by_me                 boolean,
  comment_count               integer,
  created_at                  timestamptz,
  feed_at                     timestamptz
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
    r.user_species,
    a.severity,
    a.possible_species,
    a.possible_invasive,
    a.visual_condition_assessment,
    a.incident_summary,
    a.safety_recommendations,
    a.community_warning,
    s.common_name as invasive_match_name,
    r.place_name,
    round(r.latitude::numeric, 3)::double precision  as latitude,
    round(r.longitude::numeric, 3)::double precision as longitude,
    r.user_id as author_id,
    coalesce(
      nullif(p.username, ''),
      nullif(p.full_name, ''),
      nullif(p.display_name, ''),
      'FaunaWatch user'
    ) as author_name,
    p.avatar_path as author_avatar_path,
    array(
      select ri.storage_path
      from public.report_images ri
      where ri.report_id = r.id
        -- Only the {report_id}/{filename} layout can be shown to the community.
        and public.report_id_from_image_path(ri.storage_path) = r.id
      order by ri.created_at, ri.id
    ) as photo_paths,
    (select count(*)::integer from public.report_likes l
      where l.report_id = r.id) as like_count,
    exists (
      select 1 from public.report_likes l
      where l.report_id = r.id
        and l.user_id = (select auth.uid())
    ) as liked_by_me,
    (select count(*)::integer from public.report_comments c
      where c.report_id = r.id
        and public.is_comment_visible(c.id)) as comment_count,
    r.created_at,
    f.feed_at
  from public.reports r
    cross join lateral (
      select coalesce(max(rv.decided_at), r.created_at) as feed_at
      from public.report_reviews rv
      where rv.report_id = r.id
        and rv.decision = 'approved'
    ) f
    left join public.profiles p on p.id = r.user_id
    left join lateral (
      select
        a1.severity,
        a1.possible_species,
        a1.possible_invasive,
        a1.visual_condition_assessment,
        a1.incident_summary,
        a1.safety_recommendations,
        a1.community_warning,
        a1.invasive_match_species_id
      from public.ai_analyses a1
      where a1.report_id = r.id
        and a1.status = 'completed'
      order by a1.created_at desc, a1.id desc
      limit 1
    ) a on true
    left join public.species_reference s on s.id = a.invasive_match_species_id
  where r.status = 'approved'
    and (p_report_id is null or r.id = p_report_id)
    and (
      p_before_at is null
      or (f.feed_at, r.id) < (p_before_at, p_before_id)
    )
  order by f.feed_at desc, r.id desc
  limit least(greatest(coalesce(p_limit, 10), 1), 50);
$$;

revoke execute on function public.community_feed(timestamptz, uuid, integer, uuid) from public, anon;
grant  execute on function public.community_feed(timestamptz, uuid, integer, uuid) to authenticated;
