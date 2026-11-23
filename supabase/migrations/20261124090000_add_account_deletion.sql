-- =============================================================================
-- Migration: add_account_deletion
-- Why: Settings > Delete account did nothing. Decided by the pilot on
--      2026-11-24:
--        - The user types "Delete" to confirm (capital letters don't matter).
--        - The account is deleted 7 days later. Signing in before then shows
--          "Keep my account" / "Sign out"; keeping it cancels the delete.
--        - While waiting, other users can't see the account: its profile,
--          posts, map pins, comments and chats are hidden. Admins and the
--          owner still see everything. Restoring brings it all back.
--        - After 7 days everything is deleted (an Edge Function removes the
--          photo files and then the sign-in account; the database already
--          deletes the rest through "on delete cascade").
--        - Admin accounts can't be deleted from the app.
--
-- What it adds:
--   account_deletions          one row per account that asked to be deleted
--   is_pending_deletion(uid)   true while an account is waiting to be deleted
--   request_account_deletion() "Delete" in the app; also stops push
--                              notifications by removing device tokens
--   cancel_account_deletion()  "Keep my account" in the app
--   my_account_deletion()      the caller's delete date, or null
--
-- What it changes (hiding while waiting; no change for anyone else):
--   profiles select policy, is_comment_visible(), community_reports(),
--   community_feed() (and so public_profile_gallery(), which reuses it),
--   list_chat_threads(), open_chat(), send_chat_message().
--   Each function keeps its parameters and result columns, so the app keeps
--   working before and after this is applied.
--
-- Copied from the latest definitions:
--   community_reports(), community_feed():
--     20261122110000_round_community_locations_to_100m.sql
--   is_comment_visible(): 20261027000800_create_comments.sql
--   list_chat_threads(), open_chat(), send_chat_message():
--     20261104133813_create_private_chats.sql
--
-- Not hidden while waiting (no names shown, and gone after the delete):
-- likes counted on other people's posts, and hotspot numbers on the map.
--
-- Apply by hand in the SQL Editor after 20261123160000. Safe to run more
-- than once.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- The list of accounts waiting to be deleted
-- ---------------------------------------------------------------------------
-- A row stays after "Keep my account" (cancelled_at is set), so the email
-- webhook can tell "scheduled" (cancelled_at empty) from "restored" (just
-- filled in). Asking again later reuses the row with a new date. The row
-- disappears with the account when it is finally deleted.

create table if not exists public.account_deletions (
  user_id      uuid primary key references public.profiles (id) on delete cascade,
  requested_at timestamptz not null default now(),
  -- When the account is deleted. 7 days after requested_at.
  delete_after timestamptz not null,
  -- Set when the user kept their account. Null = still waiting.
  cancelled_at timestamptz
);

comment on table public.account_deletions is
  'Accounts that asked to be deleted. Waiting while cancelled_at is null; deleted for good after delete_after by the purge-deleted-accounts Edge Function.';

-- The purge job looks for waiting accounts that are due.
create index if not exists account_deletions_due_idx
  on public.account_deletions (delete_after)
  where cancelled_at is null;

alter table public.account_deletions enable row level security;

-- Users read only their own row; admins read all (Users page badge).
-- Changes go only through the functions below.
revoke all on public.account_deletions from anon, authenticated;
grant select on public.account_deletions to authenticated;

drop policy if exists "account_deletions_select_own_or_admin" on public.account_deletions;
create policy "account_deletions_select_own_or_admin"
  on public.account_deletions
  for select
  to authenticated
  using (user_id = (select auth.uid()) or public.is_admin());


-- ---------------------------------------------------------------------------
-- Helper: is this account waiting to be deleted?
-- ---------------------------------------------------------------------------
-- Stays true after delete_after until the account is actually deleted.

create or replace function public.is_pending_deletion(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.account_deletions d
    where d.user_id = p_uid
      and d.cancelled_at is null
  );
$$;

revoke execute on function public.is_pending_deletion(uuid) from public, anon;
grant  execute on function public.is_pending_deletion(uuid) to authenticated;

comment on function public.is_pending_deletion(uuid) is
  'True while the account is waiting to be deleted. Used to hide it from other users.';


-- ---------------------------------------------------------------------------
-- "Delete account" in the app
-- ---------------------------------------------------------------------------
-- Returns the delete date. Asking again while already waiting keeps the
-- first date. The app then signs the user out everywhere.

create or replace function public.request_account_deletion(p_confirmation text)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_delete_after timestamptz;
begin
  if v_uid is null then
    raise exception 'Sign in to delete your account.' using errcode = '42501';
  end if;
  if lower(btrim(coalesce(p_confirmation, ''))) <> 'delete' then
    raise exception 'Type Delete to confirm.' using errcode = '22023';
  end if;
  if exists (select 1 from public.admin_users a where a.user_id = v_uid) then
    raise exception 'Admin accounts can''t be deleted from the app.'
      using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Profile not found.' using errcode = 'P0002';
  end if;

  insert into public.account_deletions (user_id, requested_at, delete_after)
  values (v_uid, now(), now() + interval '7 days')
  on conflict (user_id) do update
    set requested_at = excluded.requested_at,
        delete_after = excluded.delete_after,
        cancelled_at = null
    -- Already waiting: keep the first date.
    where public.account_deletions.cancelled_at is not null;

  select d.delete_after into v_delete_after
  from public.account_deletions d
  where d.user_id = v_uid;

  -- No more push notifications. The app registers the phone again after
  -- "Keep my account".
  delete from public.device_tokens t where t.user_id = v_uid;

  return v_delete_after;
end;
$$;

revoke all on function public.request_account_deletion(text) from public, anon;
grant execute on function public.request_account_deletion(text) to authenticated;

comment on function public.request_account_deletion(text) is
  'Schedules the caller''s account to be deleted in 7 days. p_confirmation must be "Delete" (any case). Refused for admins. Returns the delete date.';


-- ---------------------------------------------------------------------------
-- "Keep my account" in the app
-- ---------------------------------------------------------------------------
-- True when the delete was cancelled, false when nothing was waiting.
-- Refused once the date has passed (the purge job may already be running).

create or replace function public.cancel_account_deletion()
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
    raise exception 'Sign in to keep your account.' using errcode = '42501';
  end if;

  update public.account_deletions
     set cancelled_at = now()
   where user_id = v_uid
     and cancelled_at is null
     and delete_after > now();
  if found then
    return true;
  end if;

  if public.is_pending_deletion(v_uid) then
    raise exception 'This account is already being deleted.'
      using errcode = 'P0001';
  end if;
  return false;
end;
$$;

revoke all on function public.cancel_account_deletion() from public, anon;
grant execute on function public.cancel_account_deletion() to authenticated;

comment on function public.cancel_account_deletion() is
  'Cancels the caller''s waiting account deletion. True if cancelled, false if nothing was waiting; raises once the delete date has passed.';


-- ---------------------------------------------------------------------------
-- The caller's delete date (null when not waiting)
-- ---------------------------------------------------------------------------

create or replace function public.my_account_deletion()
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select d.delete_after
  from public.account_deletions d
  where d.user_id = (select auth.uid())
    and d.cancelled_at is null;
$$;

revoke all on function public.my_account_deletion() from public, anon;
grant execute on function public.my_account_deletion() to authenticated;

comment on function public.my_account_deletion() is
  'The caller''s delete date while their account is waiting to be deleted, else null.';


-- ---------------------------------------------------------------------------
-- Hiding: profiles
-- ---------------------------------------------------------------------------
-- Was "using (true)". Now everyone except the owner and admins stops seeing
-- a waiting account (profile preview, chat search, names next to comments).

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles
  for select
  to authenticated
  using (
    id = (select auth.uid())
    or public.is_admin()
    or not public.is_pending_deletion(id)
  );


-- ---------------------------------------------------------------------------
-- Hiding: comments (also the comment counts in the feed)
-- ---------------------------------------------------------------------------

create or replace function public.is_comment_visible(p_comment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or (
      not exists (
        select 1 from public.comment_moderation cm
        where cm.comment_id = p_comment_id
          and cm.removed_at is not null
      )
      -- Account deletion: others don't see a waiting account's comments.
      and not exists (
        select 1 from public.report_comments c
        where c.id = p_comment_id
          and c.user_id <> (select auth.uid())
          and public.is_pending_deletion(c.user_id)
      )
    );
$$;

revoke execute on function public.is_comment_visible(uuid) from public, anon;
grant  execute on function public.is_comment_visible(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- Hiding: map pins and feed posts (and so the profile gallery)
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the lines marked "Account deletion".

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
-- Hiding: chats
-- ---------------------------------------------------------------------------
-- Copied unchanged except for the lines marked "Account deletion": the
-- conversation leaves the other person's Messages list, and nobody can start
-- or continue a chat with a waiting account. Messages are kept, so they come
-- back on restore.

create or replace function public.list_chat_threads()
returns table (
  id uuid, other_user_id uuid, sender_name text, avatar_path text,
  last_message text, last_message_at timestamptz, unread_count bigint, is_unread boolean
) language sql stable security definer set search_path = '' as $$
  select t.id, p.id,
    coalesce(nullif(p.username, ''), nullif(p.full_name, ''), nullif(p.display_name, ''), 'FaunaWatch user'),
    p.avatar_path, coalesce(nullif(m.body, ''), case when m.image_path is not null then 'Photo' else '' end),
    coalesce(m.created_at, t.created_at), u.n, (s.force_unread or u.n > 0)
  from public.chat_participants s
  join public.chat_threads t on t.id = s.thread_id
  join public.profiles p on p.id = case when t.user_low = auth.uid() then t.user_high else t.user_low end
  left join lateral (select cm.body, cm.image_path, cm.created_at from public.chat_messages cm
    where cm.thread_id = t.id order by cm.created_at desc, cm.id desc limit 1) m on true
  cross join lateral (select count(*) n from public.chat_messages cm
    where cm.thread_id = t.id and cm.sender_id <> auth.uid()
      and (s.last_read_at is null or cm.created_at > s.last_read_at)) u
  where s.user_id = auth.uid() and s.hidden_at is null
    -- Account deletion: hide chats with a waiting account.
    and not public.is_pending_deletion(p.id)
  order by coalesce(m.created_at, t.created_at) desc, t.id;
$$;

create or replace function public.open_chat(p_other_user_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_thread uuid;
begin
  if v_uid is null or v_uid = p_other_user_id then
    raise exception 'Choose another registered user.';
  end if;
  if public.is_suspended(v_uid) then raise exception 'Messaging is unavailable while suspended.'; end if;
  -- Account deletion: a waiting account can't be messaged.
  if public.is_pending_deletion(p_other_user_id) then
    raise exception 'Choose another registered user.';
  end if;
  insert into public.chat_threads(user_low, user_high)
    values (least(v_uid, p_other_user_id), greatest(v_uid, p_other_user_id))
    on conflict (user_low, user_high) do update set user_low = excluded.user_low
    returning id into v_thread;
  insert into public.chat_participants(thread_id, user_id)
    values (v_thread, v_uid), (v_thread, p_other_user_id) on conflict do nothing;
  -- Reopening restores only the caller's inbox entry.
  update public.chat_participants set hidden_at = null, updated_at = clock_timestamp()
    where thread_id = v_thread and user_id = v_uid;
  return v_thread;
end;
$$;

create or replace function public.send_chat_message(p_thread_id uuid, p_body text, p_message_id uuid, p_image_path text default null)
returns public.chat_messages language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_message public.chat_messages;
begin
  perform 1 from public.chat_threads where id = p_thread_id for update;
  if not public.is_chat_participant(p_thread_id) then raise exception 'Conversation unavailable.'; end if;
  if public.is_suspended(v_uid) then raise exception 'Messaging is unavailable while suspended.'; end if;
  -- Account deletion: no messages to a waiting account.
  if exists (
    select 1 from public.chat_threads t
    where t.id = p_thread_id
      and public.is_pending_deletion(
        case when t.user_low = v_uid then t.user_high else t.user_low end)
  ) then raise exception 'Conversation unavailable.'; end if;
  if p_image_path is not null and (
    p_image_path not like v_uid::text || '/' || p_thread_id::text || '/%'
    or not exists (select 1 from storage.objects where bucket_id = 'chat-images' and name = p_image_path)
  ) then raise exception 'Photo unavailable.'; end if;
  select * into v_message from public.chat_messages where id = p_message_id;
  if found then
    if v_message.thread_id <> p_thread_id or v_message.sender_id <> v_uid
      or v_message.body <> btrim(p_body) or v_message.image_path is distinct from p_image_path
    then raise exception 'Message unavailable.'; end if;
    return v_message;
  end if;
  insert into public.chat_messages(id, thread_id, sender_id, body, image_path)
    values (p_message_id, p_thread_id, v_uid, btrim(p_body), p_image_path) returning * into v_message;
  -- New messages restore hidden conversations, without removing either user's history.
  update public.chat_participants set hidden_at = null, updated_at = clock_timestamp()
    where thread_id = p_thread_id;
  return v_message;
end;
$$;

revoke all on function public.open_chat(uuid) from public, anon;
revoke all on function public.list_chat_threads() from public, anon;
revoke all on function public.send_chat_message(uuid, text, uuid, text) from public, anon;
grant execute on function public.open_chat(uuid) to authenticated;
grant execute on function public.list_chat_threads() to authenticated;
grant execute on function public.send_chat_message(uuid, text, uuid, text) to authenticated;

notify pgrst, 'reload schema';
