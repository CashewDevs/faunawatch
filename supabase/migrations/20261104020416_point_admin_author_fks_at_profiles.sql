-- =============================================================================
-- Migration: point_admin_author_fks_at_profiles
-- Why: report_reviews.decided_by, admin_notes.author_id and
--      user_sanctions.created_by reference auth.users, so PostgREST can't
--      embed the author's profile: the admin site has to look names up in a
--      second query. Pointing them at public.profiles, like reports.user_id
--      and report_comments.user_id, lets one query return the author's name.
--
-- Deleting an admin behaves as before. profiles.id cascades from auth.users,
-- and the profile's deletion then sets these columns to null, so the records
-- stay and lose only their author.
--
-- No existing rows change. Re-adding each foreign key re-checks existing rows;
-- handle_new_user() gives every user a profile, and the hosted database has no
-- author without one (checked 2026-11-04).
-- =============================================================================


alter table public.report_reviews
  drop constraint if exists report_reviews_decided_by_fkey,
  add constraint report_reviews_decided_by_fkey
    foreign key (decided_by) references public.profiles (id) on delete set null;

alter table public.admin_notes
  drop constraint if exists admin_notes_author_id_fkey,
  add constraint admin_notes_author_id_fkey
    foreign key (author_id) references public.profiles (id) on delete set null;

alter table public.user_sanctions
  drop constraint if exists user_sanctions_created_by_fkey,
  add constraint user_sanctions_created_by_fkey
    foreign key (created_by) references public.profiles (id) on delete set null;
