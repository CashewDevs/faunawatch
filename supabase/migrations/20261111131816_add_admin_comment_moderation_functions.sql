-- =============================================================================
-- Migration: add_admin_comment_moderation_functions
-- Why: the admin site is getting Remove, Restore and Review Flag for
--      comments. The comment_moderation policies let any admin write any
--      row directly, so two admins could overwrite each other's change
--      without noticing, and deleting a row silently restored a removed
--      comment. Moderating now goes through three functions that check the
--      comment's current state first.
--
-- Now:
--   admin_remove_comment(comment_id, reason)   (new)
--     Hides the comment from non-admins. Reason is required (at most 500
--     characters) and replaces the note. Also clears a flag, since removing
--     resolves it. Refuses a removed comment: comment_already_removed (FW409).
--   admin_restore_comment(comment_id)   (new)
--     Shows a removed comment again. The removal reason is kept as the note.
--     Refuses a comment that isn't removed: comment_not_removed (FW409).
--   admin_clear_comment_flag(comment_id)   (new)
--     Review Flag: keeps the comment and clears its flag. Refuses a comment
--     that isn't flagged: comment_not_flagged (FW409).
--   All three raise insufficient_privilege (42501) for non-admins and
--   comment_not_found (FW404) for a missing comment, record the caller in
--   moderated_by, and lock the comment so two admins can't both succeed.
--
--   comment_moderation: the admin insert, update and delete policies are
--     dropped, so it is only written through the functions above. Admins can
--     still read it. Nothing can flag a comment for now; who may flag is
--     still to be decided. Existing rows untouched.
--
--   comment_moderation.moderated_by now references public.profiles, like
--     the other admin author columns, so the admin site can show who
--     removed a comment in the same query. Deleting an admin still keeps the
--     row and sets the column to null.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- moderated_by -> profiles
-- ---------------------------------------------------------------------------

alter table public.comment_moderation
  drop constraint if exists comment_moderation_moderated_by_fkey,
  add constraint comment_moderation_moderated_by_fkey
    foreign key (moderated_by) references public.profiles (id) on delete set null;


-- ---------------------------------------------------------------------------
-- admin_remove_comment()
-- ---------------------------------------------------------------------------

create or replace function public.admin_remove_comment(
  p_comment_id uuid,
  p_reason     text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(trim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'Only admins can remove comments'
      using errcode = 'insufficient_privilege';
  end if;

  if p_comment_id is null then
    raise exception 'Choose a comment'
      using errcode = 'invalid_parameter_value';
  end if;

  if v_reason is null then
    raise exception 'A reason is required to remove a comment'
      using errcode = 'invalid_parameter_value';
  end if;

  if char_length(v_reason) > 500 then
    raise exception 'Reason must be at most 500 characters'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Serialises moderation of this comment.
  perform 1 from public.report_comments c where c.id = p_comment_id for update;

  if not found then
    raise exception 'comment_not_found'
      using errcode = 'FW404', detail = p_comment_id::text;
  end if;

  if exists (
    select 1 from public.comment_moderation cm
    where cm.comment_id = p_comment_id
      and cm.removed_at is not null
  ) then
    raise exception 'comment_already_removed'
      using errcode = 'FW409', detail = p_comment_id::text;
  end if;

  insert into public.comment_moderation
    (comment_id, is_flagged, note, removed_at, moderated_by)
  values
    (p_comment_id, false, v_reason, now(), (select auth.uid()))
  on conflict (comment_id) do update
  set is_flagged   = false,
      note         = excluded.note,
      removed_at   = excluded.removed_at,
      moderated_by = excluded.moderated_by;
end;
$$;

revoke execute on function public.admin_remove_comment(uuid, text) from public, anon;
grant  execute on function public.admin_remove_comment(uuid, text) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_restore_comment()
-- ---------------------------------------------------------------------------

create or replace function public.admin_restore_comment(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can restore comments'
      using errcode = 'insufficient_privilege';
  end if;

  if p_comment_id is null then
    raise exception 'Choose a comment'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Serialises moderation of this comment.
  perform 1 from public.report_comments c where c.id = p_comment_id for update;

  if not found then
    raise exception 'comment_not_found'
      using errcode = 'FW404', detail = p_comment_id::text;
  end if;

  update public.comment_moderation cm
  set removed_at   = null,
      moderated_by = (select auth.uid())
  where cm.comment_id = p_comment_id
    and cm.removed_at is not null;

  if not found then
    raise exception 'comment_not_removed'
      using errcode = 'FW409', detail = p_comment_id::text;
  end if;
end;
$$;

revoke execute on function public.admin_restore_comment(uuid) from public, anon;
grant  execute on function public.admin_restore_comment(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_clear_comment_flag()
-- ---------------------------------------------------------------------------

create or replace function public.admin_clear_comment_flag(p_comment_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can review comment flags'
      using errcode = 'insufficient_privilege';
  end if;

  if p_comment_id is null then
    raise exception 'Choose a comment'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Serialises moderation of this comment.
  perform 1 from public.report_comments c where c.id = p_comment_id for update;

  if not found then
    raise exception 'comment_not_found'
      using errcode = 'FW404', detail = p_comment_id::text;
  end if;

  update public.comment_moderation cm
  set is_flagged   = false,
      moderated_by = (select auth.uid())
  where cm.comment_id = p_comment_id
    and cm.is_flagged;

  if not found then
    raise exception 'comment_not_flagged'
      using errcode = 'FW409', detail = p_comment_id::text;
  end if;
end;
$$;

revoke execute on function public.admin_clear_comment_flag(uuid) from public, anon;
grant  execute on function public.admin_clear_comment_flag(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- comment_moderation: writes only through the functions above
-- ---------------------------------------------------------------------------

drop policy if exists "comment_moderation_insert_admin" on public.comment_moderation;
drop policy if exists "comment_moderation_update_admin" on public.comment_moderation;
drop policy if exists "comment_moderation_delete_admin" on public.comment_moderation;
