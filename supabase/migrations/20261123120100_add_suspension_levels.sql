-- =============================================================================
-- Migration: add_suspension_levels
-- Why: A suspension only blocked posting in the database; the app didn't
--      know about it and the user was never told. Suspensions now have a
--      reason category and a level, the user is notified, and the app can
--      read its own active suspension to show it.
--
--   Levels:
--     restricted  can browse, but can't post reports, comment, like,
--                 message, upload chat photos, or edit their profile.
--     locked      the same database blocks; the app also shows only an
--                 "Account suspended" screen.
--   Both levels are blocked by the same is_suspended() checks. The extra
--   lock of 'locked' is done by the app.
--
-- New:
--   suspension_category enum: spam, misleading_reports,
--     inappropriate_content, harassment, hate_or_threats,
--     scam_or_impersonation, other.
--   suspension_level enum: restricted, locked.
--   user_sanctions.category (null for suspensions made before this
--     migration) and user_sanctions.level (default 'restricted', so existing
--     suspensions keep working as they do today).
--   admin_suspend_user(user_id, category, level, reason, days)
--     A second version with the category and level. The admin site picks a
--     preset level per category and lets the admin change it, so the
--     database takes both. Reason (the admin's message to the user) is still
--     required. Same checks and errors as the existing version.
--     The existing admin_suspend_user(user_id, reason, days) is kept for the
--     live admin site until it is updated; it saves category null and level
--     'restricted'. Drop it in a later migration once no site calls it.
--   my_active_suspension(): the caller's active suspension (category,
--     level, reason, created_at, ends_at), no row when not suspended. Never
--     returns which admin suspended them. A locked one is returned before a
--     restricted one.
--   notify_user_sanction() trigger on user_sanctions:
--     new active suspension  -> 'account_suspended' notification
--     admin lifts it early   -> 'account_reactivated' notification
--     A suspension that simply runs out notifies nothing. send-push already
--     skips suspended users, so only the reactivation is also pushed.
--
-- Changed (behaviour):
--   profiles_update_own: suspended users can't change their profile
--     (name, bio, avatar, banner).
--   avatars_storage_insert / avatars_storage_update: suspended users can't
--     upload or replace a profile picture. Deleting their own stays allowed.
--   admin_list_users(), admin_get_user(): also return suspension_category
--     and suspension_level; admin_get_user() also returns suspended_until and
--     is_admin like admin_list_users(). Adding output columns means dropping
--     and recreating them; arguments and other columns are unchanged.
--
-- Apply after 20261123120000_add_account_notification_types.sql, which must
-- have completed first (a new enum value cannot be used in the same
-- transaction). Re-runnable. Existing rows are untouched, and no
-- notifications are created for past suspensions.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Category and level
-- ---------------------------------------------------------------------------

do $$ begin
  create type public.suspension_category as enum (
    'spam',
    'misleading_reports',
    'inappropriate_content',
    'harassment',
    'hate_or_threats',
    'scam_or_impersonation',
    'other'
  );
exception when duplicate_object then null;
end $$;

-- Declared from least to most severe, so "order by level desc" puts
-- locked first.
do $$ begin
  create type public.suspension_level as enum ('restricted', 'locked');
exception when duplicate_object then null;
end $$;

alter table public.user_sanctions
  add column if not exists category public.suspension_category;

alter table public.user_sanctions
  add column if not exists level public.suspension_level not null default 'restricted';

comment on column public.user_sanctions.category is
  'Why the user was suspended. Null for suspensions made before categories.';

comment on column public.user_sanctions.level is
  'restricted = can browse but not post, comment, like, message or edit '
  'their profile. locked = the same, and the app shows only the suspension '
  'screen.';


-- ---------------------------------------------------------------------------
-- suspension_category_label(): the English label used in notifications
-- ---------------------------------------------------------------------------

create or replace function public.suspension_category_label(
  p_category public.suspension_category
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_category
    when 'spam'                  then 'Spam'
    when 'misleading_reports'    then 'Fake or misleading reports'
    when 'inappropriate_content' then 'Inappropriate content'
    when 'harassment'            then 'Harassment or bullying'
    when 'hate_or_threats'       then 'Hate speech or threats'
    when 'scam_or_impersonation' then 'Scam or impersonation'
    when 'other'                 then 'Other'
  end;
$$;

revoke execute on function public.suspension_category_label(public.suspension_category)
  from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- admin_suspend_user(user_id, category, level, reason, days)
-- ---------------------------------------------------------------------------

create or replace function public.admin_suspend_user(
  p_user_id  uuid,
  p_category public.suspension_category,
  p_level    public.suspension_level,
  -- The admin's message to the user. Shown in the app and in the email.
  p_reason   text,
  -- Null = until an admin reactivates the user.
  p_days     integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(trim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'Only admins can suspend users'
      using errcode = 'insufficient_privilege';
  end if;

  if p_user_id is null then
    raise exception 'Choose a user'
      using errcode = 'invalid_parameter_value';
  end if;

  if p_category is null then
    raise exception 'Choose a reason category'
      using errcode = 'invalid_parameter_value';
  end if;

  if p_level is null then
    raise exception 'Choose a suspension level'
      using errcode = 'invalid_parameter_value';
  end if;

  if v_reason is null then
    raise exception 'A reason is required to suspend a user'
      using errcode = 'invalid_parameter_value';
  end if;

  if char_length(v_reason) > 500 then
    raise exception 'Reason must be at most 500 characters'
      using errcode = 'invalid_parameter_value';
  end if;

  if p_days is not null and (p_days < 1 or p_days > 365) then
    raise exception 'Days must be between 1 and 365'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Serialises suspend and reactivate calls for this user.
  perform 1 from public.profiles p where p.id = p_user_id for update;

  if not found then
    raise exception 'user_not_found'
      using errcode = 'FW404', detail = p_user_id::text;
  end if;

  if exists (select 1 from public.admin_users a where a.user_id = p_user_id) then
    raise exception 'user_is_admin'
      using errcode = 'FW403', detail = p_user_id::text;
  end if;

  if public.is_suspended(p_user_id) then
    raise exception 'user_already_suspended'
      using errcode = 'FW409', detail = p_user_id::text;
  end if;

  insert into public.user_sanctions
    (user_id, reason, created_by, ends_at, category, level)
  values (
    p_user_id,
    v_reason,
    (select auth.uid()),
    case when p_days is not null then now() + make_interval(days => p_days) end,
    p_category,
    p_level
  );
end;
$$;

revoke execute on function public.admin_suspend_user(
  uuid, public.suspension_category, public.suspension_level, text, integer
) from public, anon;
grant execute on function public.admin_suspend_user(
  uuid, public.suspension_category, public.suspension_level, text, integer
) to authenticated;


-- ---------------------------------------------------------------------------
-- my_active_suspension(): what the app shows a suspended user
-- ---------------------------------------------------------------------------

create or replace function public.my_active_suspension()
returns table (
  id         uuid,
  -- Null for suspensions made before categories.
  category   public.suspension_category,
  level      public.suspension_level,
  -- The admin's message.
  reason     text,
  created_at timestamptz,
  -- Null = until an admin reactivates the user.
  ends_at    timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id, s.category, s.level, s.reason, s.created_at, s.ends_at
  from public.user_sanctions s
  where s.user_id = (select auth.uid())
    and s.lifted_at is null
    and (s.ends_at is null or s.ends_at > now())
  order by s.level desc, s.created_at desc, s.id
  limit 1;
$$;

revoke execute on function public.my_active_suspension() from public, anon;
grant  execute on function public.my_active_suspension() to authenticated;


-- ---------------------------------------------------------------------------
-- notify_user_sanction(): tell the user when suspended or reactivated
-- ---------------------------------------------------------------------------

create or replace function public.notify_user_sanction()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days   integer;
  v_length text;
  v_reason text;
  v_body   text;
begin
  -- Notifications belong to a profile; skip quietly if there is none.
  if not exists (select 1 from public.profiles p where p.id = new.user_id) then
    return null;
  end if;

  if tg_op = 'INSERT' then
    -- Only a suspension that is in force now.
    if new.lifted_at is not null
       or (new.ends_at is not null and new.ends_at <= now()) then
      return null;
    end if;

    if new.ends_at is null then
      v_length := 'until an admin lifts the suspension';
    else
      v_days := greatest(
        1,
        round(extract(epoch from (new.ends_at - new.created_at)) / 86400)::integer
      );
      v_length := 'for ' || v_days || case when v_days = 1 then ' day' else ' days' end;
    end if;

    -- Older callers save no category; their reason is shown instead.
    v_reason := rtrim(
      coalesce(public.suspension_category_label(new.category), left(new.reason, 300)),
      '. '
    );

    if new.level = 'locked' then
      v_body := 'Reason: ' || v_reason || '. Your account is locked ' || v_length || '.';
    else
      v_body := 'Reason: ' || v_reason
        || '. You can still browse, but you can''t post, comment, like, message '
        || 'or edit your profile ' || v_length || '.';
    end if;

    insert into public.notifications (user_id, type, title, body)
    values (
      new.user_id,
      'account_suspended',
      'Your account has been suspended',
      left(v_body, 1000)
    );

  elsif tg_op = 'UPDATE' then
    -- Lifted by an admin while it was still in force.
    if old.lifted_at is null
       and new.lifted_at is not null
       and (old.ends_at is null or old.ends_at > new.lifted_at) then
      insert into public.notifications (user_id, type, title, body)
      values (
        new.user_id,
        'account_reactivated',
        'Your account is active again',
        'An admin lifted your suspension. You can post, comment and message again.'
      );
    end if;
  end if;

  return null;
end;
$$;

revoke execute on function public.notify_user_sanction() from public, anon, authenticated;

drop trigger if exists user_sanctions_notify_user on public.user_sanctions;
create trigger user_sanctions_notify_user
  after insert or update of lifted_at on public.user_sanctions
  for each row
  execute function public.notify_user_sanction();


-- ---------------------------------------------------------------------------
-- Suspended users can't change their profile or profile picture
-- ---------------------------------------------------------------------------

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (
    (select auth.uid()) = id
    and not public.is_suspended((select auth.uid()))
  )
  with check (
    (select auth.uid()) = id
    and not public.is_suspended((select auth.uid()))
  );

drop policy if exists "avatars_storage_insert" on storage.objects;
create policy "avatars_storage_insert"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.is_suspended((select auth.uid()))
  );

drop policy if exists "avatars_storage_update" on storage.objects;
create policy "avatars_storage_update"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not public.is_suspended((select auth.uid()))
  );


-- ---------------------------------------------------------------------------
-- admin_list_users(): add suspension_category and suspension_level
-- ---------------------------------------------------------------------------

drop function if exists public.admin_list_users(text, text, text, integer, integer);

create or replace function public.admin_list_users(
  -- Case-insensitive match on name, username or email. Null or blank = all.
  p_search  text    default null,
  -- 'all' | 'active' | 'suspended'
  p_status  text    default 'all',
  -- 'newest' | 'oldest' | 'name'
  p_sort    text    default 'newest',
  -- Null = no limit.
  p_limit   integer default null,
  p_offset  integer default 0
)
returns table (
  user_id             uuid,
  email               text,
  email_confirmed_at  timestamptz,
  username            text,
  full_name           text,
  display_name        text,
  avatar_path         text,
  profile_created_at  timestamptz,
  report_count        bigint,
  is_suspended        boolean,
  suspension_reason   text,
  -- End of the active suspension. Null when not suspended or when the
  -- suspension lasts until an admin reactivates the user.
  suspended_until     timestamptz,
  is_admin            boolean,
  -- The active suspension's category (null when not suspended, or for one
  -- made before categories) and level (null when not suspended).
  suspension_category public.suspension_category,
  suspension_level    public.suspension_level,
  -- Users matching the search and status, across all pages. A page past the
  -- end has no rows, and so no count.
  total_count         bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
-- The output column names above are also plpgsql variables; make bare
-- names in the query refer to table columns.
#variable_conflict use_column
declare
  v_pattern text := nullif(trim(p_search), '');
begin
  if not public.is_admin() then
    raise exception 'Only admins can list users'
      using errcode = 'insufficient_privilege';
  end if;

  if p_status is null or p_status not in ('all', 'active', 'suspended') then
    raise exception 'Unknown status: %', p_status
      using errcode = 'invalid_parameter_value';
  end if;

  if p_sort is null or p_sort not in ('newest', 'oldest', 'name') then
    raise exception 'Unknown sort: %', p_sort
      using errcode = 'invalid_parameter_value';
  end if;

  -- Searching for "50%" or "a_b" means those characters, not LIKE wildcards.
  v_pattern := '%' || replace(replace(replace(v_pattern,
    '\', '\\'),
    '%', '\%'),
    '_', '\_') || '%';

  return query
  with users as (
    select
      p.id,
      au.email::text                  as account_email,
      au.email_confirmed_at           as confirmed_at,
      p.username                      as handle,
      p.full_name                     as profile_full_name,
      p.display_name                  as legacy_name,
      p.avatar_path                   as avatar,
      p.created_at                    as joined_at,
      coalesce(
        nullif(trim(p.full_name), ''),
        nullif(trim(p.username), ''),
        nullif(trim(p.display_name), ''),
        nullif(trim(split_part(au.email::text, '@', 1)), ''),
        ''
      )                               as shown_name,
      active.sanction_id is not null  as suspended,
      active.sanction_reason,
      active.sanction_ends_at,
      active.sanction_category,
      active.sanction_level,
      exists (
        select 1 from public.admin_users a
        where a.user_id = p.id
      )                               as admin
    from public.profiles p
      join auth.users au on au.id = p.id
      -- Latest active sanction (not lifted, not expired).
      left join lateral (
        select
          s.id       as sanction_id,
          s.reason   as sanction_reason,
          s.ends_at  as sanction_ends_at,
          s.category as sanction_category,
          s.level    as sanction_level
        from public.user_sanctions s
        where s.user_id = p.id
          and s.lifted_at is null
          and (s.ends_at is null or s.ends_at > now())
        order by s.created_at desc
        limit 1
      ) active on true
  )
  select
    u.id                              as user_id,
    u.account_email                   as email,
    u.confirmed_at                    as email_confirmed_at,
    u.handle                          as username,
    u.profile_full_name               as full_name,
    u.legacy_name                     as display_name,
    u.avatar                          as avatar_path,
    u.joined_at                       as profile_created_at,
    coalesce(rc.cnt, 0)               as report_count,
    u.suspended                       as is_suspended,
    u.sanction_reason                 as suspension_reason,
    u.sanction_ends_at                as suspended_until,
    u.admin                           as is_admin,
    u.sanction_category               as suspension_category,
    u.sanction_level                  as suspension_level,
    count(*) over ()                  as total_count
  from users u
    left join (
      select user_id, count(*) as cnt
      from public.reports
      group by user_id
    ) rc on rc.user_id = u.id
  where (
      v_pattern is null
      or u.shown_name    ilike v_pattern
      or u.handle        ilike v_pattern
      or u.account_email ilike v_pattern
    )
    and (
      p_status = 'all'
      or (p_status = 'suspended') = u.suspended
    )
  order by
    case when p_sort = 'newest' then u.joined_at end desc,
    case when p_sort = 'oldest' then u.joined_at end asc,
    case when p_sort = 'name' then lower(u.shown_name) end asc,
    -- Keeps pages stable when users share a date or name.
    u.id
  limit p_limit
  offset p_offset;
end;
$$;

revoke execute on function public.admin_list_users(text, text, text, integer, integer) from public, anon;
grant  execute on function public.admin_list_users(text, text, text, integer, integer) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_get_user(): the same suspension fields as admin_list_users()
-- ---------------------------------------------------------------------------

drop function if exists public.admin_get_user(uuid);

create or replace function public.admin_get_user(p_user_id uuid)
returns table (
  user_id             uuid,
  email               text,
  email_confirmed_at  timestamptz,
  username            text,
  full_name           text,
  display_name        text,
  avatar_path         text,
  profile_created_at  timestamptz,
  report_count        bigint,
  is_suspended        boolean,
  suspension_reason   text,
  suspended_until     timestamptz,
  is_admin            boolean,
  suspension_category public.suspension_category,
  suspension_level    public.suspension_level
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Only admins can read user details'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  select
    p.id                              as user_id,
    au.email::text,
    au.email_confirmed_at,
    p.username,
    p.full_name,
    p.display_name,
    p.avatar_path,
    p.created_at                      as profile_created_at,
    (
      select count(*) from public.reports r
      where r.user_id = p.id
    )                                 as report_count,
    active.sanction_id is not null    as is_suspended,
    active.sanction_reason            as suspension_reason,
    active.sanction_ends_at           as suspended_until,
    exists (
      select 1 from public.admin_users a
      where a.user_id = p.id
    )                                 as is_admin,
    active.sanction_category          as suspension_category,
    active.sanction_level             as suspension_level
  from public.profiles p
    join auth.users au on au.id = p.id
    -- Latest active sanction (not lifted, not expired).
    left join lateral (
      select
        s.id       as sanction_id,
        s.reason   as sanction_reason,
        s.ends_at  as sanction_ends_at,
        s.category as sanction_category,
        s.level    as sanction_level
      from public.user_sanctions s
      where s.user_id = p.id
        and s.lifted_at is null
        and (s.ends_at is null or s.ends_at > now())
      order by s.created_at desc
      limit 1
    ) active on true
  where p.id = p_user_id;
end;
$$;

revoke execute on function public.admin_get_user(uuid) from public, anon;
grant  execute on function public.admin_get_user(uuid) to authenticated;
