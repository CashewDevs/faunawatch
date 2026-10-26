-- =============================================================================
-- Migration: create_admin_users
-- Why: Establish admin identity. A separate table (not a profiles column) is
--      used because profiles_update_own would let users promote themselves.
--      The is_admin() helper is a security definer function that all subsequent
--      admin-gated policies and RPCs will call.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.admin_users (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

comment on table public.admin_users is
  'Admin role table. No client RLS policies — only is_admin() and the '
  'Supabase Dashboard read/write this table. The first admin is added '
  'manually via the Dashboard SQL Editor after creating the user in Auth.';

alter table public.admin_users enable row level security;
-- Intentionally no client policies: only is_admin() and the dashboard
-- read/write this table.


-- ---------------------------------------------------------------------------
-- is_admin() helper
-- ---------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  );
$$;

-- Only authenticated users may call is_admin().
-- Revoke from public and anon to prevent unauthenticated probing.
revoke execute on function public.is_admin() from public, anon;
grant  execute on function public.is_admin() to authenticated;
