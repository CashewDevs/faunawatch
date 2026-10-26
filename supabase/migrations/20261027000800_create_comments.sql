-- =============================================================================
-- Migration: create_comments
-- Why: Users can comment on approved reports (the only user-to-user
--      interaction; no messaging). Admins can flag or remove comments with a
--      note. Removed comments are hidden from non-admin users via a security
--      definer helper function.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_comments
-- ---------------------------------------------------------------------------

create table if not exists public.report_comments (
  id         uuid primary key default gen_random_uuid(),

  report_id  uuid not null references public.reports   (id) on delete cascade,
  user_id    uuid not null references public.profiles   (id) on delete cascade,

  body       text not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.report_comments is
  'User comments on reports. Only allowed on approved reports. '
  'Removed comments are hidden from non-admins via is_comment_visible().';

create trigger report_comments_updated_at
  before update on public.report_comments
  for each row execute function public.set_updated_at();

create index if not exists report_comments_report_id_idx
  on public.report_comments (report_id);

create index if not exists report_comments_user_id_idx
  on public.report_comments (user_id);


-- ---------------------------------------------------------------------------
-- comment_moderation: admin-only flagging/removal
-- ---------------------------------------------------------------------------

create table if not exists public.comment_moderation (
  -- One moderation record per comment — comment_id is the PK.
  comment_id    uuid primary key references public.report_comments (id) on delete cascade,

  is_flagged    boolean not null default false,
  note          text,

  -- When set, the comment is considered "removed" and hidden from non-admins.
  removed_at    timestamptz,

  moderated_by  uuid references auth.users (id) on delete set null,

  updated_at    timestamptz not null default now()
);

comment on table public.comment_moderation is
  'Admin-only comment moderation. When removed_at is set, the comment is '
  'hidden from non-admin users. Only admins can flag or remove comments (OQ 2).';

create trigger comment_moderation_updated_at
  before update on public.comment_moderation
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- is_comment_visible(): security definer helper
-- ---------------------------------------------------------------------------

-- Returns true if the comment should be visible to the current user.
-- Admins always see all comments. Non-admins see comments that have not
-- been removed (no comment_moderation row, or removed_at is null).

create or replace function public.is_comment_visible(p_comment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_admin()
    or not exists (
      select 1 from public.comment_moderation cm
      where cm.comment_id = p_comment_id
        and cm.removed_at is not null
    );
$$;


-- ---------------------------------------------------------------------------
-- RLS — report_comments
-- ---------------------------------------------------------------------------

alter table public.report_comments enable row level security;

-- Select: anyone who can see the report, excluding removed comments.
-- The parent report visibility check is deferred to migration 10
-- (restrict_location_and_images). For now, any authenticated user with
-- a visible (non-removed) comment can read it.
create policy "report_comments_select_visible"
  on public.report_comments
  for select
  to authenticated
  using (public.is_comment_visible(id));

-- Insert: own row, report must be approved.
-- Suspension check is added in migration 9 (create_user_sanctions).
create policy "report_comments_insert_own"
  on public.report_comments
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.reports r
      where r.id = report_comments.report_id
        and r.status = 'approved'
    )
  );

-- Update: own comment only.
create policy "report_comments_update_own"
  on public.report_comments
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Delete: own comment only.
create policy "report_comments_delete_own"
  on public.report_comments
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);


-- ---------------------------------------------------------------------------
-- RLS — comment_moderation (admin only — OQ 2 resolution)
-- ---------------------------------------------------------------------------

alter table public.comment_moderation enable row level security;

create policy "comment_moderation_select_admin"
  on public.comment_moderation
  for select
  to authenticated
  using (public.is_admin());

create policy "comment_moderation_insert_admin"
  on public.comment_moderation
  for insert
  to authenticated
  with check (public.is_admin());

create policy "comment_moderation_update_admin"
  on public.comment_moderation
  for update
  to authenticated
  using (public.is_admin());

create policy "comment_moderation_delete_admin"
  on public.comment_moderation
  for delete
  to authenticated
  using (public.is_admin());
