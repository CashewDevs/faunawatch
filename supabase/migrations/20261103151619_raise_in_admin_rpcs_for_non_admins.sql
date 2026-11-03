-- =============================================================================
-- Migration: raise_in_admin_rpcs_for_non_admins
-- Why: create_admin_rpcs intended every admin RPC to raise when the caller
--      is not an admin, but admin_list_users() and admin_sector_stats()
--      only filtered with "where public.is_admin()", so a non-admin got an
--      empty result that looks like "no data" and hides permission bugs.
--      Both are rewritten in plpgsql to raise insufficient_privilege
--      (42501, which PostgREST returns as 403) before doing any work.
--
-- Same signatures, return columns and results for admins. The queries are
-- unchanged apart from the old is_admin() filter being dropped.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- admin_list_users()
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_users()
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
-- The output column names above are also plpgsql variables; make bare
-- names in the query refer to table columns.
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Only admins can list users'
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
    coalesce(rc.cnt, 0)               as report_count,
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
    left join (
      select user_id, count(*) as cnt
      from public.reports
      group by user_id
    ) rc on rc.user_id = p.id;
end;
$$;

revoke execute on function public.admin_list_users() from public, anon;
grant  execute on function public.admin_list_users() to authenticated;


-- ---------------------------------------------------------------------------
-- admin_sector_stats()
-- ---------------------------------------------------------------------------

create or replace function public.admin_sector_stats(
  p_from_ts    timestamptz,
  p_to_ts      timestamptz,
  p_cell_size  double precision default 0.1,  -- ~11 km at the equator
  p_min_count  integer default 3
)
returns table (
  cell_lat     double precision,
  cell_lng     double precision,
  report_count bigint,
  categories   jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not public.is_admin() then
    raise exception 'Only admins can read sector stats'
      using errcode = 'insufficient_privilege';
  end if;

  -- Two-level aggregation:
  --   1. cell_cats: count per (cell, category)
  --   2. Roll up to per-cell totals with category breakdown as JSONB
  return query
  with cell_cats as (
    select
      floor(r.latitude  / p_cell_size) * p_cell_size + p_cell_size / 2 as c_lat,
      floor(r.longitude / p_cell_size) * p_cell_size + p_cell_size / 2 as c_lng,
      r.category::text as cat,
      count(*)::bigint as cnt
    from public.reports r
    where r.created_at between p_from_ts and p_to_ts
    group by c_lat, c_lng, r.category
  )
  select
    cc.c_lat                          as cell_lat,
    cc.c_lng                          as cell_lng,
    sum(cc.cnt)::bigint               as report_count,
    jsonb_object_agg(cc.cat, cc.cnt)  as categories
  from cell_cats cc
  group by cc.c_lat, cc.c_lng
  having sum(cc.cnt) >= p_min_count;
end;
$$;

revoke execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) from public, anon;
grant  execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) to authenticated;
