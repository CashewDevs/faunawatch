-- Optional cleanup after 20261123170000_add_profile_tags.sql.
-- Apply manually in Supabase's SQL editor. Existing tags and RLS are preserved.
-- All tags can now be chosen freely, so the activity summary is no longer used.

drop function if exists public.my_profile_tag_activity();

comment on column public.profiles.profile_tag is
  'Optional public interest tag freely chosen by its owner. '
  'Dog Lover, Cat Lover, or Spotter; the owner may change or clear it.';

notify pgrst, 'reload schema';
