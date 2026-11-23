-- Persist the user's short profile bio (up to 50 characters, matching the app UI).
-- Nullable column preserves existing profiles; RLS remains unchanged.
alter table public.profiles
  add column if not exists bio text;

alter table public.profiles
  drop constraint if exists profiles_bio_length;

alter table public.profiles
  add constraint profiles_bio_length
    check (bio is null or char_length(bio) <= 50);

comment on column public.profiles.bio is
  'Optional short user bio (max 50 characters). Nullable.';

notify pgrst, 'reload schema';
