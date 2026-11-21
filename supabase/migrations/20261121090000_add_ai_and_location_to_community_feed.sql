-- =============================================================================
-- Migration: add_ai_and_location_to_community_feed
-- Why: Posts in the app's For You feed get an "AI analysis" sheet, and tapping
--      a post's location opens the community map at that spot. Both need more
--      from community_feed() than it returned.
--
-- ⚠️ BEHAVIOUR CHANGE: more AI text is public for approved reports.
--   create_community_feed (20261112100000) kept these ai_analyses columns
--   private. community_feed() now also returns them, from the same completed
--   analysis it already used:
--     visual_condition_assessment, incident_summary, safety_recommendations,
--     community_warning, and invasive_match_name (species_reference
--     common_name of invasive_match_species_id).
--   Decided by the team on 2026-11-21: everyone who can see an approved post
--   can see its AI analysis. STILL NOT returned: responder_briefing (meant
--   for responders and admins), validation, provider, model, prompt_version,
--   and reports.user_notes.
--
-- latitude and longitude: approximate only.
--   Rounded to 2 decimals (about 1 km), exactly like community_reports(), so
--   this reveals nothing the community map doesn't already show for the same
--   approved report (the map's pins already carry the report id). Exact
--   coordinates are still never returned.
--
-- The returned columns change, so the function is dropped and recreated
-- (create or replace cannot change a function's result columns). Its
-- parameters, ordering, paging and approved-only rule are unchanged, and the
-- grants are restored below. Apply by hand in the SQL Editor; the app reads
-- the new columns when present and works without them.
-- =============================================================================

drop function if exists public.community_feed(timestamptz, uuid, integer, uuid);

create function public.community_feed(
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
    round(r.latitude::numeric, 2)::double precision  as latitude,
    round(r.longitude::numeric, 2)::double precision as longitude,
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
