-- =============================================================================
-- Migration: add_admin_suspend_and_reactivate_user
-- Why: the admin site is getting Suspend and Reactivate. The user_sanctions
--      policies let any admin insert, change or delete any sanction, so an
--      admin could suspend another admin or themselves, stack a second
--      suspension on an active one, or erase the record. Suspending now goes
--      through two functions that refuse those cases.
--
-- Now:
--   admin_suspend_user(user_id, reason, days)   (new)
--     Reason is required (at most 500 characters). Days is 1-365, or null
--     for "until reactivated". Refuses:
--       an admin, including the caller          user_is_admin (FW403)
--       a user who is already suspended         user_already_suspended (FW409)
--       a user who doesn't exist                user_not_found (FW404)
--   admin_reactivate_user(user_id)   (new)
--     Lifts the user's active suspension (sets lifted_at). Refuses a user
--     who isn't suspended: user_not_suspended (FW409).
--   Both raise insufficient_privilege (42501) for non-admins and lock the
--   user's profile row, so two admins acting at once can't both succeed.
--
--   user_sanctions: the admin insert, update and delete policies are dropped,
--     so sanctions are only written through the two functions above. Admins
--     and the suspended user can still read them. Existing rows untouched.
--
--   admin_list_users(): also returns suspended_until (null = until
--     reactivated) and is_admin, so the site can show the end date and hide
--     Suspend for admins. Adding output columns means dropping and recreating
--     the function; its arguments and other columns are unchanged.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- admin_suspend_user()
-- ---------------------------------------------------------------------------

create or replace function public.admin_suspend_user(
  p_user_id uuid,
  p_reason  text,
  -- Null = until an admin reactivates the user.
  p_days    integer default null
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

  insert into public.user_sanctions (user_id, reason, created_by, ends_at)
  values (
    p_user_id,
    v_reason,
    (select auth.uid()),
    case when p_days is not null then now() + make_interval(days => p_days) end
  );
end;
$$;

revoke execute on function public.admin_suspend_user(uuid, text, integer) from public, anon;
grant  execute on function public.admin_suspend_user(uuid, text, integer) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_reactivate_user()
-- ---------------------------------------------------------------------------

create or replace function public.admin_reactivate_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can reactivate users'
      using errcode = 'insufficient_privilege';
  end if;

  if p_user_id is null then
    raise exception 'Choose a user'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Serialises suspend and reactivate calls for this user.
  perform 1 from public.profiles p where p.id = p_user_id for update;

  if not found then
    raise exception 'user_not_found'
      using errcode = 'FW404', detail = p_user_id::text;
  end if;

  -- Lifts every active sanction, in case older data has more than one.
  update public.user_sanctions s
  set lifted_at = now()
  where s.user_id = p_user_id
    and s.lifted_at is null
    and (s.ends_at is null or s.ends_at > now());

  if not found then
    raise exception 'user_not_suspended'
      using errcode = 'FW409', detail = p_user_id::text;
  end if;
end;
$$;

revoke execute on function public.admin_reactivate_user(uuid) from public, anon;
grant  execute on function public.admin_reactivate_user(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- user_sanctions: writes only through the functions above
-- ---------------------------------------------------------------------------

drop policy if exists "user_sanctions_insert_admin" on public.user_sanctions;
drop policy if exists "user_sanctions_update_admin" on public.user_sanctions;
drop policy if exists "user_sanctions_delete_admin" on public.user_sanctions;


-- ---------------------------------------------------------------------------
-- admin_list_users(): add suspended_until and is_admin
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
  user_id            uuid,
  email              text,
  email_confirmed_at timestamptz,
  username           text,
  full_name          text,
  display_name       text,
  avatar_path        text,
  profile_created_at timestamptz,
  report_count       bigint,
  is_suspended       boolean,
  suspension_reason  text,
  -- End of the active suspension. Null when not suspended or when the
  -- suspension lasts until an admin reactivates the user.
  suspended_until    timestamptz,
  is_admin           boolean,
  -- Users matching the search and status, across all pages. A page past the
  -- end has no rows, and so no count.
  total_count        bigint
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
      exists (
        select 1 from public.admin_users a
        where a.user_id = p.id
      )                               as admin
    from public.profiles p
      join auth.users au on au.id = p.id
      -- Latest active sanction (not lifted, not expired).
      left join lateral (
        select
          s.id      as sanction_id,
          s.reason  as sanction_reason,
          s.ends_at as sanction_ends_at
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
