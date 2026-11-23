-- =============================================================================
-- Migration: add_private_posts
-- Why: Settings > Privacy > "Private posts". When a user turns it on, other
--      people visiting their profile can't see their posts. The account
--      owner and admins still can.
--
--      Only the profile gallery is hidden. The Feed and the map
--      (community_feed / community_reports) still show the posts, so wildlife
--      alerts keep reaching the community.
--
-- Apply by hand in the SQL editor after 20261123120100_add_suspension_levels.sql.
-- Safe to run more than once.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- The setting, one per account (off for everyone to start with)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists posts_private boolean not null default false;

comment on column public.profiles.posts_private is
  'When true, public_profile_gallery() returns no posts to anyone except the owner and admins. Feed and map are unaffected.';


-- ---------------------------------------------------------------------------
-- Saving the setting
-- ---------------------------------------------------------------------------
-- A dedicated function rather than a plain profile update, because
-- profiles_update_own blocks every profile edit while a user is suspended.
-- Hiding your own posts is a privacy choice, not posting, so it stays allowed.
-- It only ever changes this one column of the caller's own row.

create or replace function public.set_posts_private(p_private boolean)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Sign in to change this setting.' using errcode = '42501';
  end if;
  if p_private is null then
    raise exception 'p_private must be true or false.' using errcode = '22004';
  end if;

  update public.profiles
     set posts_private = p_private
   where id = v_uid;

  if not found then
    raise exception 'Profile not found.' using errcode = 'P0002';
  end if;

  return p_private;
end;
$$;

revoke all on function public.set_posts_private(boolean) from public, anon;
grant execute on function public.set_posts_private(boolean) to authenticated;

comment on function public.set_posts_private(boolean) is
  'Turns the caller''s Private posts setting on or off. Allowed while suspended. Returns the saved value.';


-- ---------------------------------------------------------------------------
-- Profile gallery: nothing for visitors when the account is private
-- ---------------------------------------------------------------------------
-- Same signature and columns as 20261121233000, so the app needs no change
-- to keep working. Only the new privacy condition in "page" is added.

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
      -- Private posts: visitors get nothing; the owner and admins still see.
      and (
        p_user_id = (select auth.uid())
        or public.is_admin()
        or not coalesce(
          (select pr.posts_private from public.profiles pr where pr.id = p_user_id),
          false
        )
      )
      and (p_category is null or r.category = p_category)
      and (
        (p_before_at is null and p_before_id is null)
        or (r.created_at, r.id) < (p_before_at, p_before_id)
      )
    order by r.created_at desc, r.id desc
    limit least(greatest(coalesce(p_limit, 12), 1), 50)
  )
  -- Keep the gallery's projection stable when community_feed adds columns.
  -- Reuse only these public fields: no coordinates, notes, or admin data.
  -- Author/category filtering and keyset pagination happen before these calls.
  select
    f.id,
    f.category,
    f.description,
    f.user_species,
    f.severity,
    f.possible_species,
    f.possible_invasive,
    f.place_name,
    f.author_id,
    f.author_name,
    f.author_avatar_path,
    f.photo_paths,
    f.like_count,
    f.liked_by_me,
    f.comment_count,
    f.created_at,
    f.feed_at
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
) is 'Signed-in community access to one author''s approved posts, newest submission first. Empty for visitors when the author turned on Private posts. Reuses community_feed public fields.';

notify pgrst, 'reload schema';
