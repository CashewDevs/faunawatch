-- =============================================================================
-- Migration: add_admin_get_user_and_user_stats
-- Why: the admin site loaded every user just to show one reporter's verified
--      badge and to count users for the stat cards. Now that
--      admin_list_users() returns pages, these two RPCs answer those questions
--      directly. Like the other admin RPCs, both raise insufficient_privilege
--      (42501) for non-admins.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- admin_get_user(): one user, with the same fields as admin_list_users().
-- No row when the user doesn't exist.
-- ---------------------------------------------------------------------------

create or replace function public.admin_get_user(p_user_id uuid)
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
  suspension_reason  text
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
    -- Active sanction check
    exists (
      select 1 from public.user_sanctions s
      where s.user_id = p.id
        and s.lifted_at is null
        and (s.ends_at is null or s.ends_at > now())
    )                                 as is_suspended,
    (
      select s.reason from public.user_sanctions s
      where s.user_id = p.id
        and s.lifted_at is null
        and (s.ends_at is null or s.ends_at > now())
      order by s.created_at desc
      limit 1
    )                                 as suspension_reason
  from public.profiles p
    join auth.users au on au.id = p.id
  where p.id = p_user_id;
end;
$$;

revoke execute on function public.admin_get_user(uuid) from public, anon;
grant  execute on function public.admin_get_user(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_user_stats(): the counts behind the admin site's user stat cards.
-- Months are UTC calendar months, as on the site; "last 7 days" is a rolling
-- window. Always one row.
-- ---------------------------------------------------------------------------

create or replace function public.admin_user_stats()
returns table (
  total_users     bigint,
  active_users    bigint,
  suspended_users bigint,
  new_this_month  bigint,
  new_last_month  bigint,
  new_last_7_days bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_this_month timestamptz := date_trunc('month', now(), 'UTC');
  v_last_month timestamptz := date_trunc('month', v_this_month - interval '1 day', 'UTC');
begin
  if not public.is_admin() then
    raise exception 'Only admins can read user stats'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  with users as (
    select
      p.created_at as joined_at,
      -- Active sanction check
      exists (
        select 1 from public.user_sanctions s
        where s.user_id = p.id
          and s.lifted_at is null
          and (s.ends_at is null or s.ends_at > now())
      ) as suspended
    from public.profiles p
  )
  select
    count(*)                                                                     as total_users,
    count(*) filter (where not u.suspended)                                      as active_users,
    count(*) filter (where u.suspended)                                          as suspended_users,
    count(*) filter (where u.joined_at >= v_this_month)                          as new_this_month,
    count(*) filter (where u.joined_at >= v_last_month and u.joined_at < v_this_month) as new_last_month,
    count(*) filter (where u.joined_at >= now() - interval '7 days')             as new_last_7_days
  from users u;
end;
$$;

revoke execute on function public.admin_user_stats() from public, anon;
grant  execute on function public.admin_user_stats() to authenticated;
