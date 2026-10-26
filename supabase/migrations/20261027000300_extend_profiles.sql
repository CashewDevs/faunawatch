-- =============================================================================
-- Migration: extend_profiles
-- Why: Add username (unique, format-checked) and full_name to profiles.
--      Document the preset:<name> avatar convention. display_name is kept
--      (dropping it is destructive and needs separate approval).
-- =============================================================================


-- ---------------------------------------------------------------------------
-- New columns
-- ---------------------------------------------------------------------------

-- username: unique handle, nullable until the user sets one.
-- Format: 3-30 chars, alphanumeric + underscores only.
alter table public.profiles
  add column if not exists username text unique;

alter table public.profiles
  add constraint profiles_username_format
  check (username ~ '^[a-zA-Z0-9_]{3,30}$');

-- full_name: display-oriented, no format constraint.
alter table public.profiles
  add column if not exists full_name text;

comment on column public.profiles.username is
  'Unique handle. 3-30 chars, alphanumeric + underscores. Nullable until set.';

comment on column public.profiles.full_name is
  'User''s full name for display purposes. Nullable.';


-- ---------------------------------------------------------------------------
-- Avatar path convention
-- ---------------------------------------------------------------------------

-- Preset avatars use the distinguishable value `preset:<name>` (e.g.
-- `preset:bunny`). Uploaded avatars keep the storage path
-- `{user_id}/{filename}`. No database constraint is added because both
-- formats are valid text; the convention is enforced in the app layer.
comment on column public.profiles.avatar_path is
  'Path inside the avatars storage bucket, OR a preset identifier in the '
  'form preset:<name> (e.g. preset:bunny). Uploaded avatars use '
  '{user_id}/{filename}.';


-- ---------------------------------------------------------------------------
-- display_name note
-- ---------------------------------------------------------------------------

-- display_name is NOT dropped. The signup flow should be updated to write
-- username (unique handle) and full_name (display name) instead, but
-- display_name remains for backward compatibility until a coordinated
-- removal is approved.
comment on column public.profiles.display_name is
  'Legacy display name. New code should use username (handle) and full_name. '
  'Will be removed in a future migration once all clients are updated.';
