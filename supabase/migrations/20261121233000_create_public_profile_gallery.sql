-- Public account galleries: approved reports only, filtered before pagination.
-- Apply manually after 20261112100000_create_community_feed.sql and its
-- prerequisites. No notification changes, new tables, or wider table RLS.

create index if not exists reports_public_gallery_idx
  on public.reports (user_id, created_at desc, id desc)
  where status = 'approved';

create or replace function public.public_profile_gallery(
  p_user_id uuid,
  p_before_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 12,
  p_category public.report_category default null
)
returns table (
  id uuid,
  category public.report_category,
  description text,
  user_species text,
  severity public.severity_level,
  possible_species jsonb,
  possible_invasive boolean,
  place_name text,
  author_id uuid,
  author_name text,
  author_avatar_path text,
  photo_paths text[],
  like_count integer,
  liked_by_me boolean,
  comment_count integer,
  created_at timestamptz,
  feed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with page as materialized (
    select r.id
    from public.reports r
    where (select auth.uid()) is not null
      and r.user_id = p_user_id
      and r.status = 'approved'
      and (p_category is null or r.category = p_category)
      and (
        (p_before_at is null and p_before_id is null)
        or (r.created_at, r.id) < (p_before_at, p_before_id)
      )
    order by r.created_at desc, r.id desc
    limit least(greatest(coalesce(p_limit, 12), 1), 50)
  )
  -- Reuse the feed's public projection: no coordinates, notes, or admin data.
  -- Author/category filtering and keyset pagination happen before these calls.
  select f.*
  from page p
  cross join lateral public.community_feed(
    p_report_id => p.id,
    p_limit => 1
  ) f
  order by f.created_at desc, f.id desc;
$$;

revoke all on function public.public_profile_gallery(
  uuid, timestamptz, uuid, integer, public.report_category
) from public, anon;
grant execute on function public.public_profile_gallery(
  uuid, timestamptz, uuid, integer, public.report_category
) to authenticated;

comment on function public.public_profile_gallery(
  uuid, timestamptz, uuid, integer, public.report_category
) is 'Signed-in community access to one author''s approved posts, newest submission first. Reuses community_feed public fields.';
