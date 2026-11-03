-- =============================================================================
-- Migration: keep_admin_records_when_admin_deleted
-- Why: report_reviews.decided_by, admin_notes.author_id and
--      user_sanctions.created_by were "not null ... on delete cascade" to
--      auth.users. Deleting an admin's account therefore deleted every
--      approve/decline decision and note they made, and every suspension
--      they issued (lifting those suspensions). The columns now become
--      nullable with "on delete set null", like
--      comment_moderation.moderated_by: the records stay and lose only
--      their author.
--
-- The insert policies now also require the author to be the caller, so
-- admins can't file a record under another admin or with no author; a
-- null author only ever means "deleted admin". admin_decide_report() is
-- security definer and already writes auth.uid().
--
-- No existing rows change. Re-adding each foreign key re-checks existing
-- rows, which all reference existing users already.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_reviews.decided_by
-- ---------------------------------------------------------------------------

alter table public.report_reviews
  alter column decided_by drop not null,
  drop constraint if exists report_reviews_decided_by_fkey,
  add constraint report_reviews_decided_by_fkey
    foreign key (decided_by) references auth.users (id) on delete set null;

drop policy if exists "report_reviews_insert_admin" on public.report_reviews;
create policy "report_reviews_insert_admin"
  on public.report_reviews
  for insert
  to authenticated
  with check (
    public.is_admin()
    and decided_by = (select auth.uid())
  );


-- ---------------------------------------------------------------------------
-- admin_notes.author_id
-- ---------------------------------------------------------------------------

alter table public.admin_notes
  alter column author_id drop not null,
  drop constraint if exists admin_notes_author_id_fkey,
  add constraint admin_notes_author_id_fkey
    foreign key (author_id) references auth.users (id) on delete set null;

drop policy if exists "admin_notes_insert_admin" on public.admin_notes;
create policy "admin_notes_insert_admin"
  on public.admin_notes
  for insert
  to authenticated
  with check (
    public.is_admin()
    and author_id = (select auth.uid())
  );


-- ---------------------------------------------------------------------------
-- user_sanctions.created_by
-- ---------------------------------------------------------------------------

alter table public.user_sanctions
  alter column created_by drop not null,
  drop constraint if exists user_sanctions_created_by_fkey,
  add constraint user_sanctions_created_by_fkey
    foreign key (created_by) references auth.users (id) on delete set null;

drop policy if exists "user_sanctions_insert_admin" on public.user_sanctions;
create policy "user_sanctions_insert_admin"
  on public.user_sanctions
  for insert
  to authenticated
  with check (
    public.is_admin()
    and created_by = (select auth.uid())
  );
