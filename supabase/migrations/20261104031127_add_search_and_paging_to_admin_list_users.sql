-- =============================================================================
-- Migration: add_search_and_paging_to_admin_list_users
-- Why: admin_list_users() returned every user at once, so the admin site
--      searched, filtered, sorted and paged in the browser. That stops being
--      workable with thousands of users. The RPC now does that work and
--      reports how many users matched.
--
-- Called with no arguments it still returns everyone, plus the new total_count
-- column, so the current admin site keeps working until it moves to paging.
--
-- The old no-argument function has to be dropped: Postgres treats a different
-- argument list as a separate function, and leaving both would make a
-- no-argument call ambiguous. No table data is touched.
--
-- Search and sort use the name the admin site shows (getProfileDisplayName in
-- faunawatch-admin): full name, username, legacy display name, then the part
-- of the email before the "@".
-- =============================================================================


drop function if exists public.admin_list_users();

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
      -- Active sanction check
      exists (
        select 1 from public.user_sanctions s
        where s.user_id = p.id
          and s.lifted_at is null
          and (s.ends_at is null or s.ends_at > now())
      )                               as suspended
    from public.profiles p
      join auth.users au on au.id = p.id
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
    (
      select s.reason from public.user_sanctions s
      where s.user_id = u.id
        and s.lifted_at is null
        and (s.ends_at is null or s.ends_at > now())
      order by s.created_at desc
      limit 1
    )                                 as suspension_reason,
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
