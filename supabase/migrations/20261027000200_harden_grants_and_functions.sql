-- =============================================================================
-- Migration: harden_grants_and_functions
-- Why: The initial schema left anon with default privileges on public tables
--      (no anon policies exist, so nothing breaks). This migration revokes
--      those grants and sets default privileges so future tables also deny
--      anon. It also recreates handle_new_user() with a secure search_path.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Revoke anon access to all existing public tables
-- ---------------------------------------------------------------------------

-- No anon policies exist, so revoking table-level grants is non-breaking.
revoke all privileges on all tables in schema public from anon;

-- Ensure future tables also do not grant anon access by default.
alter default privileges in schema public revoke all on tables from anon;


-- ---------------------------------------------------------------------------
-- Recreate handle_new_user() with hardened search_path
-- ---------------------------------------------------------------------------

-- The original (migration 20261016120100) used `set search_path = public`
-- which is less restrictive than the empty search_path convention used by
-- all security definer functions in this project. Recreate it with
-- `set search_path = ''` and fully qualified table names.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- The trigger on auth.users already exists and does not need to be recreated.
-- CREATE OR REPLACE on the function body is sufficient.
