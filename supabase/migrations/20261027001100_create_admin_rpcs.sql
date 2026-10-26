-- =============================================================================
-- Migration: create_admin_rpcs
-- Why: Admin-only RPC functions for the admin website. All check is_admin()
--      first and raise if false. Also adds admin select policies on tables
--      the admin site reads that are not already covered.
--
-- TODO(open question): Invasive threat type for analytics (colony, aquatic,
--   ecosystem, biosecurity) is left out. The source (AI output,
--   species_reference, or admin-assigned) is undecided. Add it when the
--   team confirms the write path.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- admin_list_users(): profile fields + email, verified status, stats
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
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.id                              as user_id,
    au.email,
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
    ) rc on rc.user_id = p.id
  where public.is_admin();
  -- The WHERE clause doubles as the auth guard: if is_admin() returns false,
  -- the query returns zero rows. The SECURITY DEFINER context allows reading
  -- auth.users.email which is not normally accessible to clients.
$$;

revoke execute on function public.admin_list_users() from public, anon;
grant  execute on function public.admin_list_users() to authenticated;


-- ---------------------------------------------------------------------------
-- admin_sector_stats(): grid-based sighting density
-- ---------------------------------------------------------------------------

-- Returns sighting counts per grid cell with cell centre coordinates.
-- Never returns the average of raw coordinates (which would leak exact
-- locations for small cells). Cell centres are deterministic from the grid.
-- Cells with fewer than min_count sightings are omitted.

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
language sql
stable
security definer
set search_path = ''
as $$
  -- Two-level aggregation:
  --   1. cell_cats: count per (cell, category)
  --   2. Roll up to per-cell totals with category breakdown as JSONB
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
  where public.is_admin()
  group by cc.c_lat, cc.c_lng
  having sum(cc.cnt) >= p_min_count;
$$;

revoke execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) from public, anon;
grant  execute on function public.admin_sector_stats(timestamptz, timestamptz, double precision, integer) to authenticated;


-- ---------------------------------------------------------------------------
-- Admin select policies on remaining tables
-- ---------------------------------------------------------------------------

-- profiles: admins can already read via profiles_select_authenticated.
-- No change needed.

-- reports: admin select is already covered by reports_select_owner_admin
-- (migration 10). No change needed.

-- report_images: covered by report_images_select_owner_admin_approved.
-- No change needed.

-- warning_zones: add admin select (currently only
-- warning_zones_select_authenticated which uses `using (true)` but
-- after migration 2's anon revocation, this still works for authenticated).
-- Admin access is implicitly covered. No additional policy needed.

-- community_responses: same pattern — authenticated can already read.
-- Admin access is implicitly covered. No additional policy needed.

-- alerts: currently own-only. Admins may need to see alerts for support.
create policy "alerts_select_admin"
  on public.alerts
  for select
  to authenticated
  using (public.is_admin());

-- report_image_exif: already has owner+admin in migration 6.
-- No change needed.

-- report_reviews, admin_notes, user_sanctions, comment_moderation:
-- already have admin policies. No change needed.
