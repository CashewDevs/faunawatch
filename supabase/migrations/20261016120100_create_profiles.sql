-- =============================================================================
-- Migration: create_profiles
-- Why: User identity and public profile data. Tied 1-to-1 with auth.users.
--      A trigger auto-creates a profile row on signup so the app never needs
--      to do an explicit insert after registration.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  -- Primary key mirrors auth.users(id) — not gen_random_uuid() because the
  -- identity is owned by Supabase Auth.
  id            uuid primary key references auth.users (id) on delete cascade,

  display_name  text,
  avatar_path   text,   -- path inside the avatars storage bucket

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()

  -- OPEN QUESTION: the SRS mentions "basic credentials and personal details"
  -- without listing specific fields beyond what is modelled here.
  -- Only display_name and avatar_path are added until the user specifies more.
  -- TODO(open question): are any other profile fields required (e.g. phone,
  --   bio, notification preferences)?
);

comment on table public.profiles is
  'One row per authenticated user. Created automatically on signup via trigger.';


-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- Auto-create profile on signup
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;

-- Any authenticated user can read any profile (display name / avatar for map)
create policy "profiles_select_authenticated"
  on public.profiles
  for select
  to authenticated
  using (true);
  -- NOTE: using (true) is intentional here — display names and avatars are
  -- community-visible. If private profiles are later required, narrow this.

-- Users can update only their own profile row
create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Insert is handled exclusively by the signup trigger (security definer).
-- No client insert policy is needed.

-- Delete is intentionally not exposed to clients. Account deletion should go
-- through a server-side function that also cleans up storage objects, etc.
