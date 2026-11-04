-- =============================================================================
-- Migration: add_place_name_to_reports
-- Why: Reports store coordinates only, so admins reviewing a post have no idea
--      where it is without opening a map. The app now saves the area around
--      the reported point, looked up from Mapbox when the post is submitted.
--
-- Area only: barangay or locality, city, province. Never a street address,
-- because this describes where a person was standing.
--
-- Null when the lookup failed or the app didn't send one, and on every existing
-- report; the admin site then shows coordinates. No existing rows change.
--
-- Only the owner and admins can read it, through the existing reports policies.
-- community_reports() lists its columns and deliberately doesn't return this:
-- the community sees a ~1 km grid, and a barangay name could narrow that down.
-- =============================================================================


alter table public.reports
  add column if not exists place_name text;

alter table public.reports
  drop constraint if exists reports_place_name_length;

alter table public.reports
  add constraint reports_place_name_length
  check (char_length(trim(place_name)) between 1 and 200);

comment on column public.reports.place_name is
  'Area around the reported point, e.g. "Lusod, Kabayan, Benguet". Barangay or '
  'locality, city, province only: never a street address. Null when unknown. '
  'Owner and admin only; not returned by community_reports().';
