-- =============================================================================
-- Migration: add_edit_hide_delete_posts
-- Why: Users can now edit, hide and delete their own posts. Decided by the
--      pilot on 2026-11-24:
--        - Hide (approved posts only): the post leaves the Feed, the map and
--          the public profile for everyone except admins. The owner sees it
--          on their own profile with a "Hidden" badge. Nobody else can like
--          or comment on it. Unhide brings it back. Hotspot numbers on the
--          map still count it (like accounts waiting to be deleted).
--        - Edit caption (approved or pending): the post keeps its status.
--        - Edit photos (approved or pending, 1 to 3 photos): a new cover
--          photo must come with a new AI analysis, which also sets the
--          category. Saving puts the post back to pending for an admin.
--        - Delete (any status): uses the existing reports_delete_own policy;
--          likes, comments, notifications, reviews and photo rows go with it
--          ("on delete cascade"). The app removes the photo files first.
--        - Suspended users can hide and delete, but not edit.
--
-- New:
--   reports.hidden_at          set while the owner hides the post
--   reports.photos_edited_at   last time the owner changed the photos
--                              (the admin site shows "Edited after approval")
--   set_my_report_hidden(report_id, hidden)
--   update_my_report_caption(report_id, description)
--   apply_my_report_photo_edit(report_id, photos, analysis, category)
--   guard_report_owner_fields() trigger: hidden_at and photos_edited_at only
--     change through the functions above (or an admin).
--
-- Changed:
--   Hidden posts left out of: community_feed(), community_reports(),
--   public_profile_gallery(), and the helpers can_view_report_media(),
--   can_view_report_comments(), is_report_approved() (likes and comments),
--   plus the ai_analyses select policy.
--   report-images storage: owners may also upload photos to their approved
--   posts (for a photo edit) and delete their own posts' photo files in any
--   status (for deleting a post, or cleaning up a failed edit).
--   guard_report_status(): also lets the owner move approved -> pending,
--   inside apply_my_report_photo_edit() only.
--   notify_report_pending(): "Your edited post is pending review".
--
-- Copied from the latest definitions (only the marked lines are new):
--   community_reports(), community_feed(): 20261124090000_add_account_deletion.sql
--   public_profile_gallery(): 20261123150000_add_private_posts.sql
--   can_view_report_media(): 20261103155245_report_image_paths_without_user_id.sql
--   can_view_report_comments(), is_report_approved(): 20261111144014_fix_comment_access_rules.sql
--   ai_analyses_select_owner_admin_approved: 20261027001000_restrict_location_and_images.sql
--   report-images storage insert/delete: 20261103155245_report_image_paths_without_user_id.sql
--   guard_report_status(): 20261111150721_add_report_change_requests.sql
--   notify_report_pending(): 20261120090100_add_like_and_pending_notifications.sql
--
-- Each changed function keeps its parameters and result columns, so the app
-- keeps working before and after this is applied.
--
-- Apply by hand in the SQL Editor after 20261124150000. Safe to run more
-- than once.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- New columns
-- ---------------------------------------------------------------------------

alter table public.reports
  add column if not exists hidden_at timestamptz,
  add column if not exists photos_edited_at timestamptz;

comment on column public.reports.hidden_at is
  'Set while the owner hides this post. Hidden posts are left out of the feed, map and public profiles for everyone except admins; the owner sees them on their own profile.';
comment on column public.reports.photos_edited_at is
  'Last time the owner changed the photos (apply_my_report_photo_edit). That also put the post back to pending.';


-- ---------------------------------------------------------------------------
-- Guard: the owner changes these columns only through the functions below
-- ---------------------------------------------------------------------------
-- reports_update_own lets an owner update a pending report directly, so
-- without this they could set the columns by hand. The functions below set
-- faunawatch.owner_editing_post to the report id for their own transaction.

create or replace function public.guard_report_owner_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or public.is_admin() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.hidden_at := null;
    new.photos_edited_at := null;
    return new;
  end if;

  if (new.hidden_at is distinct from old.hidden_at
      or new.photos_edited_at is distinct from old.photos_edited_at)
     and coalesce(current_setting('faunawatch.owner_editing_post', true), '') <> old.id::text
  then
    raise exception 'Use the post menu to hide or edit a post'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

revoke execute on function public.guard_report_owner_fields() from public, anon, authenticated;

drop trigger if exists guard_report_owner_fields_trigger on public.reports;
create trigger guard_report_owner_fields_trigger
  before insert or update on public.reports
  for each row execute function public.guard_report_owner_fields();


-- ---------------------------------------------------------------------------
-- Status guard: also the owner's photo edit (approved -> pending)
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the block marked "Photo edit".

create or replace function public.guard_report_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    -- The reporter resubmitting, inside resubmit_report() only.
    if old.status = 'changes_requested'
       and new.status = 'pending'
       and coalesce(current_setting('faunawatch.resubmitting_report', true), '') = old.id::text
       and old.user_id = (select auth.uid())
       and not exists (
         select 1 from public.report_change_requests cr
         where cr.report_id = old.id
           and cr.resolution is null
       )
    then
      return new;
    end if;

    -- Photo edit: the owner sends an approved post back for review, inside
    -- apply_my_report_photo_edit() only.
    if old.status = 'approved'
       and new.status = 'pending'
       and coalesce(current_setting('faunawatch.owner_editing_post', true), '') = old.id::text
       and old.user_id = (select auth.uid())
    then
      return new;
    end if;

    if not public.is_admin() then
      raise exception 'Only admins can change report status';
    end if;
    if coalesce(current_setting('faunawatch.deciding_report', true), '') <> 'on' then
      raise exception 'Report status can only be changed through the moderation functions';
    end if;
  end if;
  return new;
end;
$$;


-- ---------------------------------------------------------------------------
-- Notification: an edited post is pending review again
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the branch marked "Photo edit".

create or replace function public.notify_report_pending()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_title := 'Your report is pending review';
  elsif old.status = 'changes_requested'
        and new.user_id = (select auth.uid()) then
    -- The owner resubmitting. An admin withdrawing the request is not
    -- notified (auth.uid() is the admin).
    v_title := 'Your resubmitted report is pending review';
  elsif old.status = 'approved'
        and new.user_id = (select auth.uid()) then
    -- Photo edit: the owner changed the photos of an approved post.
    v_title := 'Your edited post is pending review';
  else
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body, report_id)
  values (
    new.user_id,
    'report_status',
    v_title,
    'We''ll let you know once it has been reviewed.',
    new.id
  );

  return new;
end;
$$;

revoke execute on function public.notify_report_pending() from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- Hiding: photos, comments, likes and AI analyses of hidden posts
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the lines marked "Hidden posts".

create or replace function public.can_view_report_media(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or exists (
      select 1 from public.reports r
      where r.id = p_report_id
        and (
          r.user_id = (select auth.uid())
          -- Hidden posts: only the owner and admins.
          or (r.status = 'approved' and r.hidden_at is null)
        )
    );
$$;

create or replace function public.can_view_report_comments(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or exists (
      select 1 from public.reports r
      where r.id = p_report_id
        and (
          r.user_id = (select auth.uid())
          -- Hidden posts: only the owner and admins.
          or (r.status = 'approved' and r.hidden_at is null)
        )
    );
$$;

-- Used by the like and comment policies: nobody else can like or comment on
-- a hidden post. The owner still can.
create or replace function public.is_report_approved(p_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.status = 'approved'
      -- Hidden posts: only the owner.
      and (r.hidden_at is null or r.user_id = (select auth.uid()))
  );
$$;

drop policy if exists "ai_analyses_select_owner_admin_approved" on public.ai_analyses;
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
          -- Hidden posts: only the owner and admins.
          or (r.status = 'approved' and r.hidden_at is null)
        )
    )
  );


-- ---------------------------------------------------------------------------
-- Hiding: map pins and feed posts
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the lines marked "Hidden posts".

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
    -- Account deletion: others don't see a waiting account's pins.
    and (
      r.user_id = (select auth.uid())
      or public.is_admin()
      or not public.is_pending_deletion(r.user_id)
    )
    -- Hidden posts: no pin for anyone, the owner included (they find the
    -- post on their profile). Admins still see it.
    and (r.hidden_at is null or public.is_admin())
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
    -- Account deletion: others don't see a waiting account's posts.
    and (
      r.user_id = (select auth.uid())
      or public.is_admin()
      or not public.is_pending_deletion(r.user_id)
    )
    -- Hidden posts: out of everyone's feed. The owner can still open their
    -- own by id (the profile's post viewer); admins see everything.
    and (
      r.hidden_at is null
      or public.is_admin()
      or (p_report_id is not null and r.user_id = (select auth.uid()))
    )
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
-- Hiding: public profile gallery
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the lines marked "Hidden posts" and the
-- comment at the end.

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
      -- Hidden posts: left out for everyone, the owner included, so it shows
      -- what visitors see. Admins still see them.
      and (r.hidden_at is null or public.is_admin())
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
) is 'Signed-in community access to one author''s approved posts, newest submission first. Empty for visitors when the author turned on Private posts. Hidden posts are left out (admins still see them). Reuses community_feed public fields.';


-- ---------------------------------------------------------------------------
-- Photo files (report-images bucket)
-- ---------------------------------------------------------------------------

-- Upload: a photo edit of an approved post uploads its new photos before
-- apply_my_report_photo_edit() puts it back to pending. The files are not
-- shown anywhere until that function adds them to report_images.
-- Runs as the caller; owners can read their own reports.
create or replace function public.can_add_report_photo(p_report_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.user_id = (select auth.uid())
      and r.status = 'approved'
      and not public.is_suspended((select auth.uid()))
  );
$$;

-- Delete: the owner removes their own post's photo files in any status, when
-- deleting the post (files first, then the report) or after a photo edit.
create or replace function public.owns_report(p_report_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.user_id = (select auth.uid())
  );
$$;

revoke execute on function public.can_add_report_photo(uuid) from public, anon;
grant  execute on function public.can_add_report_photo(uuid) to authenticated;
revoke execute on function public.owns_report(uuid) from public, anon;
grant  execute on function public.owns_report(uuid) to authenticated;

drop policy if exists "report_images_storage_insert" on storage.objects;
create policy "report_images_storage_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'report-images'
    and (
      public.can_edit_report_media(public.report_id_from_image_path(name))
      or public.can_add_report_photo(public.report_id_from_image_path(name))
    )
  );

drop policy if exists "report_images_storage_delete" on storage.objects;
create policy "report_images_storage_delete"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'report-images'
    and public.owns_report(public.report_id_from_image_path(name))
  );


-- ---------------------------------------------------------------------------
-- Hide / unhide
-- ---------------------------------------------------------------------------
-- Allowed while suspended: hiding is a privacy choice, not posting.
-- Only approved posts can be hidden (others aren't public); unhiding works in
-- any status, so a hidden post that went back to pending can be shown again.

create or replace function public.set_my_report_hidden(
  p_report_id uuid,
  p_hidden    boolean
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_owner  uuid;
  v_status public.report_status;
begin
  if v_uid is null then
    raise exception 'Sign in to change your post.' using errcode = '42501';
  end if;
  if p_hidden is null then
    raise exception 'p_hidden must be true or false.' using errcode = '22004';
  end if;

  select r.user_id, r.status into v_owner, v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found or v_owner <> v_uid then
    raise exception 'report_not_found' using errcode = 'FW404';
  end if;
  if p_hidden and v_status <> 'approved' then
    raise exception 'report_not_public' using errcode = 'FW409';
  end if;

  perform set_config('faunawatch.owner_editing_post', p_report_id::text, true);

  update public.reports
     set hidden_at = case when p_hidden then coalesce(hidden_at, now()) end
   where id = p_report_id;
end;
$$;

revoke all on function public.set_my_report_hidden(uuid, boolean) from public, anon;
grant execute on function public.set_my_report_hidden(uuid, boolean) to authenticated;

comment on function public.set_my_report_hidden(uuid, boolean) is
  'Hides (approved posts only) or shows the caller''s own post. Errors: report_not_found (FW404), report_not_public (FW409).';


-- ---------------------------------------------------------------------------
-- Edit caption
-- ---------------------------------------------------------------------------
-- Approved and pending posts; the status doesn't change. Blank text removes
-- the caption.

create or replace function public.update_my_report_caption(
  p_report_id   uuid,
  p_description text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_owner  uuid;
  v_status public.report_status;
begin
  if v_uid is null then
    raise exception 'Sign in to change your post.' using errcode = '42501';
  end if;

  select r.user_id, r.status into v_owner, v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found or v_owner <> v_uid then
    raise exception 'report_not_found' using errcode = 'FW404';
  end if;
  if public.is_suspended(v_uid) then
    raise exception 'account_suspended' using errcode = 'FW403';
  end if;
  if v_status not in ('approved', 'pending') then
    raise exception 'report_not_editable' using errcode = 'FW409';
  end if;

  update public.reports
     -- Leading/trailing whitespace of any kind is dropped, like the app does.
     set description = nullif(regexp_replace(coalesce(p_description, ''), '^\s+|\s+$', '', 'g'), '')
   where id = p_report_id;
end;
$$;

revoke all on function public.update_my_report_caption(uuid, text) from public, anon;
grant execute on function public.update_my_report_caption(uuid, text) to authenticated;

comment on function public.update_my_report_caption(uuid, text) is
  'Changes the caption of the caller''s own approved or pending post. Errors: report_not_found (FW404), account_suspended (FW403), report_not_editable (FW409).';


-- ---------------------------------------------------------------------------
-- Edit photos
-- ---------------------------------------------------------------------------
-- The app first uploads the new photo files to {report_id}/..., then calls
-- this once. Everything below happens together or not at all:
--   - photos left out are removed from report_images (their paths are
--     returned, so the app can delete the files)
--   - new photos are added, with their EXIF
--   - the photos get the order given (the first is the cover)
--   - a new cover needs a new AI analysis; it replaces the old completed
--     analysis, and the category follows it
--   - the post goes (back) to pending and photos_edited_at is set
--
-- p_photos, in display order, 1 to 3 items, each either
--   {"image_id": "<existing report_images id>"}  keep this photo
--   {"storage_path": "<report_id>/<file>", "size_bytes": 123,
--    "fingerprint": "...", "exif": {...}}          a newly uploaded photo
-- p_analysis: the ai_analyses row the app would insert for a new post
--   (AiIdentification.toAnalysisRow); required only when the cover changes.
-- p_category: the category from that analysis; ignored without a new cover.

create or replace function public.apply_my_report_photo_edit(
  p_report_id uuid,
  p_photos    jsonb,
  p_analysis  jsonb default null,
  p_category  public.report_category default null
)
returns text[]
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid           uuid := (select auth.uid());
  v_owner         uuid;
  v_status        public.report_status;
  v_old_cover     uuid;
  v_cover_changed boolean;
  v_keep          uuid[] := '{}';
  v_new_paths     text[] := '{}';
  v_removed       text[];
  v_item          jsonb;
  v_index         bigint;
  v_image_id      uuid;
  v_path          text;
  v_now           timestamptz := clock_timestamp();
begin
  if v_uid is null then
    raise exception 'Sign in to change your post.' using errcode = '42501';
  end if;

  select r.user_id, r.status into v_owner, v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found or v_owner <> v_uid then
    raise exception 'report_not_found' using errcode = 'FW404';
  end if;
  if public.is_suspended(v_uid) then
    raise exception 'account_suspended' using errcode = 'FW403';
  end if;
  if v_status not in ('approved', 'pending') then
    raise exception 'report_not_editable' using errcode = 'FW409';
  end if;

  if jsonb_typeof(p_photos) is distinct from 'array'
     or jsonb_array_length(p_photos) not between 1 and 3 then
    raise exception 'A post needs 1 to 3 photos.' using errcode = 'check_violation';
  end if;

  -- Check every item before changing anything.
  for v_item in select value from jsonb_array_elements(p_photos) loop
    if jsonb_typeof(v_item->'image_id') = 'string' then
      v_image_id := (v_item->>'image_id')::uuid;
      if v_image_id = any (v_keep) or not exists (
        select 1 from public.report_images ri
        where ri.id = v_image_id and ri.report_id = p_report_id
      ) then
        raise exception 'photo_not_found' using errcode = 'FW404', detail = v_image_id::text;
      end if;
      v_keep := v_keep || v_image_id;

    elsif jsonb_typeof(v_item->'storage_path') = 'string' then
      v_path := v_item->>'storage_path';
      if public.report_id_from_image_path(v_path) is distinct from p_report_id
         or v_path = any (v_new_paths)
         or exists (select 1 from public.report_images ri where ri.storage_path = v_path)
         or not exists (
           select 1 from storage.objects o
           where o.bucket_id = 'report-images' and o.name = v_path
         )
      then
        raise exception 'photo_not_uploaded' using errcode = 'FW409', detail = v_path;
      end if;
      v_new_paths := v_new_paths || v_path;

    else
      raise exception 'Each photo needs an image_id or a storage_path.'
        using errcode = 'check_violation';
    end if;
  end loop;

  select ri.id into v_old_cover
    from public.report_images ri
    where ri.report_id = p_report_id
    order by ri.created_at, ri.id
    limit 1;

  v_cover_changed := v_old_cover is null
    or (p_photos->0->>'image_id') is null
    or (p_photos->0->>'image_id')::uuid <> v_old_cover;

  if v_cover_changed and p_analysis is null then
    raise exception 'analysis_required' using errcode = 'FW409';
  end if;
  if not v_cover_changed and p_analysis is not null then
    raise exception 'analysis_without_new_cover' using errcode = 'FW409';
  end if;

  -- Lets guard_report_status() and guard_report_owner_fields() accept the
  -- changes below, for this report and this transaction only.
  perform set_config('faunawatch.owner_editing_post', p_report_id::text, true);

  -- Pending first: the photo and analysis rules below are those of a post
  -- under review.
  update public.reports
     set status           = 'pending',
         photos_edited_at = now(),
         category         = case when v_cover_changed
                                 then coalesce(p_category, category)
                                 else category end
   where id = p_report_id;

  with removed as (
    delete from public.report_images ri
    where ri.report_id = p_report_id
      and not (ri.id = any (v_keep))
    returning ri.storage_path
  )
  select coalesce(array_agg(storage_path), '{}') into v_removed from removed;

  -- Feed, map and admin site order photos by created_at, then id.
  for v_item, v_index in
    select value, ordinality from jsonb_array_elements(p_photos) with ordinality
  loop
    if jsonb_typeof(v_item->'image_id') = 'string' then
      update public.report_images
         set created_at = v_now + make_interval(secs => v_index / 1000.0)
       where id = (v_item->>'image_id')::uuid;
    else
      insert into public.report_images (
        report_id, storage_path, content_type, size_bytes, fingerprint, created_at
      )
      values (
        p_report_id,
        v_item->>'storage_path',
        'image/webp',
        (v_item->>'size_bytes')::bigint,
        v_item->>'fingerprint',
        v_now + make_interval(secs => v_index / 1000.0)
      )
      returning id into v_image_id;

      if jsonb_typeof(v_item->'exif') = 'object' and v_item->'exif' <> '{}'::jsonb then
        insert into public.report_image_exif (
          image_id, taken_at, gps_latitude, gps_longitude, gps_altitude_m,
          device_make, device_model, camera_settings, flash_fired
        )
        select
          v_image_id, e.taken_at, e.gps_latitude, e.gps_longitude, e.gps_altitude_m,
          e.device_make, e.device_model, e.camera_settings, e.flash_fired
        from jsonb_populate_record(null::public.report_image_exif, v_item->'exif') e;
      end if;
    end if;
  end loop;

  if v_cover_changed then
    -- A post has at most one completed analysis
    -- (ai_analyses_one_completed_per_report_idx), and the old one described
    -- the old cover, so it is replaced.
    delete from public.ai_analyses
     where report_id = p_report_id
       and status = 'completed';

    -- Same columns as the app's AiIdentification.toAnalysisRow().
    insert into public.ai_analyses (
      report_id, status, animal_present, possible_species,
      visual_condition_assessment, severity, safety_recommendations,
      possible_invasive, invasive_match_species_id, provider, model,
      prompt_version, is_preliminary
    )
    select
      p_report_id, 'completed', a.animal_present, a.possible_species,
      a.visual_condition_assessment, a.severity, a.safety_recommendations,
      a.possible_invasive, a.invasive_match_species_id, a.provider, a.model,
      a.prompt_version, coalesce(a.is_preliminary, true)
    -- report_id and id from the app are ignored: it is always this post.
    from jsonb_populate_record(null::public.ai_analyses, p_analysis - 'report_id' - 'id') a;
  end if;

  return v_removed;
end;
$$;

revoke all on function public.apply_my_report_photo_edit(uuid, jsonb, jsonb, public.report_category) from public, anon;
grant execute on function public.apply_my_report_photo_edit(uuid, jsonb, jsonb, public.report_category) to authenticated;

comment on function public.apply_my_report_photo_edit(uuid, jsonb, jsonb, public.report_category) is
  'Replaces the photos of the caller''s own approved or pending post and puts it back to pending. A new cover needs a new AI analysis. Returns the storage paths of removed photos. Errors: report_not_found / photo_not_found (FW404), account_suspended (FW403), report_not_editable / photo_not_uploaded / analysis_required / analysis_without_new_cover (FW409).';

notify pgrst, 'reload schema';
