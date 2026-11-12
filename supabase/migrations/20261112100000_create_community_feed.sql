-- =============================================================================
-- Migration: create_community_feed
-- Why: The For You tab of the app's Feed. Once a report is approved it shows
--      up there for every signed-in user, with real likes and real comments.
--      Replaces the app's single hard-coded sample post.
--
-- ⚠️ BEHAVIOUR CHANGE (reverses OQ 8): feed posts show who wrote them.
--   restrict_location_and_images (20261027001000) decided that approved
--   reports stay anonymous ("OQ 8 resolution: stay anonymous"), and
--   report_image_paths_without_user_id (20261103155245) kept the user id out of
--   photo paths for the same reason. The team has now decided that the feed
--   shows the author's name and avatar. community_feed() therefore returns
--   author_id, author_name and author_avatar_path. Only the feed changes:
--   community_reports() (the map) is NOT touched and still returns no author.
--   Profiles were already readable by every signed-in user
--   (profiles_select_authenticated), so this reveals no new profile data, only
--   which approved report belongs to whom.
--
-- ⚠️ BEHAVIOUR CHANGE: place_name is no longer owner/admin-only.
--   add_place_name_to_reports (20261104035846) kept reports.place_name away
--   from the community. The feed now returns it exactly as stored ("barangay
--   or locality, city, province", never a street address) for approved
--   reports. Splitting it into city and province is not reliable, because
--   missing parts are left out ("Barangay 666, Manila" and "Kabayan, Benguet"
--   have the same shape), so it is not split. community_reports() still does
--   NOT return it. Nothing here returns exact coordinates: community_feed()
--   has no latitude or longitude column. A null place_name stays null and the
--   app shows "Approximate location".
--
-- Not exposed (and still private): user_notes, perch_height_m, host_tree,
--   is_night_observation, elevation_m, exact coordinates, report_image_exif,
--   admin_notes, report_reviews (decider, decline reasons), ai_status and the
--   other ai_analyses columns (validation, summaries, safety text, model).
--   reports can still only be read directly by the owner and admins.
--
-- community_feed(p_before_at, p_before_id, p_limit, p_report_id)
--   Approved reports, newest first, in pages. Keyset paging: pass the
--   feed_at and id of the last row of the previous page as p_before_at and
--   p_before_id (both, or neither for the first page). p_limit is clamped to
--   1..50. p_report_id returns only that report, if it is approved (the app
--   uses it to open a report from the map).
--   Order: feed_at desc, id desc, where feed_at is the time of the latest
--   'approved' report_reviews row (report_reviews.decided_at), falling back to
--   reports.created_at when a report has none (approved before reviews were
--   recorded). A report that is taken down and approved again moves up.
--   Columns: id, category, description, user_species; severity,
--   possible_species and possible_invasive from the report's completed
--   ai_analyses row (null without one); place_name; author_id, author_name
--   and author_avatar_path; photo_paths (storage paths in report-images,
--   oldest first, report_images has no position column); like_count,
--   liked_by_me, comment_count (comments the caller may see); created_at and
--   feed_at.
--   author_name uses the same fallbacks as list_chat_threads() and
--   notification_actor_name(): username, full_name, display_name, then
--   'FaunaWatch user'. author_avatar_path is profiles.avatar_path as stored:
--   either preset:<name> or a path in the avatars bucket.
--   Security definer, because reports' own RLS only lets owners and admins
--   read them. It only ever returns approved reports.
--
-- report_likes: one row per (report, user). A user can only add or remove
--   their own like, only on an approved report, and not while suspended
--   (is_suspended, like report_comments). Clients can read only their own
--   rows; counts and liked_by_me come from community_feed(). There is no
--   update. No notifications are created for likes.
--
-- Comments need no schema change: the app reads and writes report_comments
--   (see fix_comment_access_rules) and the notify_report_comment trigger from
--   create_notifications fires on its own. The table has no replies,
--   reactions or images, so the app does not offer them.
--
-- ai_analyses: ai_analyses_select_owner_admin_approved already lets any
--   signed-in user read the analyses of approved reports, which is what this
--   function relies on, and it returns only severity, possible_species and
--   possible_invasive. Nothing private is added. (Direct queries could already
--   read the other columns of approved reports' analyses; this migration does
--   not change that.)
--
-- New: report_likes, community_feed(), report_reviews_report_decided_idx.
-- Changed: nothing existing, apart from the place_name column comment.
-- Apply after 20261112090000_create_notifications.sql. Existing rows are not
-- touched.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_likes
-- ---------------------------------------------------------------------------

create table if not exists public.report_likes (
  report_id  uuid not null references public.reports  (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,

  created_at timestamptz not null default now(),

  primary key (report_id, user_id)
);

comment on table public.report_likes is
  'A user''s like on an approved report. Users can only add or remove their '
  'own. Counts come from community_feed().';

-- The primary key covers lookups and counts by report; this one covers
-- "which reports did this user like" and cascades from profiles.
create index if not exists report_likes_user_id_idx
  on public.report_likes (user_id);

alter table public.report_likes enable row level security;

revoke all on public.report_likes from anon, authenticated;
grant select, insert, delete on public.report_likes to authenticated;

drop policy if exists "report_likes_select_own" on public.report_likes;
create policy "report_likes_select_own"
  on public.report_likes
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- is_report_approved() is security definer, so reports' RLS doesn't hide the
-- report from people who are not its owner.
drop policy if exists "report_likes_insert_own" on public.report_likes;
create policy "report_likes_insert_own"
  on public.report_likes
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.is_report_approved(report_id)
    and not public.is_suspended((select auth.uid()))
  );

drop policy if exists "report_likes_delete_own" on public.report_likes;
create policy "report_likes_delete_own"
  on public.report_likes
  for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    and public.is_report_approved(report_id)
    and not public.is_suspended((select auth.uid()))
  );

-- No update policy or grant: a like is either there or not.


-- ---------------------------------------------------------------------------
-- Index for the approval time used to order the feed
-- ---------------------------------------------------------------------------

create index if not exists report_reviews_report_decided_idx
  on public.report_reviews (report_id, decision, decided_at desc);


-- ---------------------------------------------------------------------------
-- community_feed()
-- ---------------------------------------------------------------------------

create or replace function public.community_feed(
  p_before_at timestamptz default null,
  p_before_id uuid        default null,
  p_limit     integer     default 10,
  p_report_id uuid        default null
)
returns table (
  id                  uuid,
  category            public.report_category,
  description         text,
  user_species        text,
  severity            public.severity_level,
  possible_species    jsonb,
  possible_invasive   boolean,
  place_name          text,
  author_id           uuid,
  author_name         text,
  author_avatar_path  text,
  photo_paths         text[],
  like_count          integer,
  liked_by_me         boolean,
  comment_count       integer,
  created_at          timestamptz,
  feed_at             timestamptz
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
    r.place_name,
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
      select a1.severity, a1.possible_species, a1.possible_invasive
      from public.ai_analyses a1
      where a1.report_id = r.id
        and a1.status = 'completed'
      order by a1.created_at desc, a1.id desc
      limit 1
    ) a on true
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


-- ---------------------------------------------------------------------------
-- place_name comment: now shown in the feed
-- ---------------------------------------------------------------------------

comment on column public.reports.place_name is
  'Area around the reported point, e.g. "Lusod, Kabayan, Benguet". Barangay or '
  'locality, city, province only: never a street address. Null when unknown. '
  'Returned for approved reports by community_feed() exactly as stored, and to '
  'the owner and admins. Not returned by community_reports().';
