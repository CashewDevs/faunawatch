-- =============================================================================
-- Migration: add_account_purge_helpers
-- Why: Delete account, Phase 3. The Edge Function purge-deleted-accounts runs
--      every hour and deletes the accounts whose 7 days are up. It needs two
--      answers only the database can give:
--        - which accounts are due (never admins, as a safety net), and
--        - which stored files belong to an account. Report photos are stored
--          as {report_id}/{filename}, so they can't be found by user folder.
--      Then it removes the files through the Storage API and deletes the
--      sign-in account; "on delete cascade" removes all the rows.
--
-- Both functions are for the service role only (the Edge Function). Signed-in
-- users and visitors can't call them.
--
-- Apply by hand in the SQL Editor after 20261124090000_add_account_deletion.sql.
-- Safe to run more than once.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Accounts whose delete date has passed, oldest first
-- ---------------------------------------------------------------------------

create or replace function public.due_account_deletions(p_limit integer default 20)
returns table (user_id uuid, delete_after timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select d.user_id, d.delete_after
  from public.account_deletions d
  where d.cancelled_at is null
    and d.delete_after <= now()
    -- Admins can't ask to be deleted; skip one that became admin meanwhile.
    and not exists (
      select 1 from public.admin_users a where a.user_id = d.user_id
    )
  order by d.delete_after, d.user_id
  limit least(greatest(coalesce(p_limit, 20), 1), 100);
$$;

revoke all on function public.due_account_deletions(integer) from public, anon, authenticated;
grant execute on function public.due_account_deletions(integer) to service_role;

comment on function public.due_account_deletions(integer) is
  'Service role only. Waiting account deletions whose date has passed (admins excluded), oldest first.';


-- ---------------------------------------------------------------------------
-- Every stored file that goes when an account is deleted
-- ---------------------------------------------------------------------------
--   avatars        {user_id}/{file}
--   report-images  {report_id}/{file} for the user's reports, and the older
--                  {user_id}/{report_id}/{file}
--   chat-images    {sender_id}/{thread_id}/{file}: the user's own photos and
--                  the photos others sent in the user's chats (those chats
--                  are deleted with the account)

create or replace function public.account_storage_objects(p_user_id uuid)
returns table (bucket_id text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select o.bucket_id, o.name
  from storage.objects o
  where p_user_id is not null
    and (
      (
        o.bucket_id in ('avatars', 'report-images', 'chat-images')
        and split_part(o.name, '/', 1) = p_user_id::text
      )
      or (
        o.bucket_id = 'report-images'
        and public.report_id_from_image_path(o.name) in (
          select r.id from public.reports r where r.user_id = p_user_id
        )
      )
      or (
        o.bucket_id = 'chat-images'
        and split_part(o.name, '/', 2) in (
          select t.id::text from public.chat_threads t
          where p_user_id in (t.user_low, t.user_high)
        )
      )
    )
  order by o.bucket_id, o.name;
$$;

revoke all on function public.account_storage_objects(uuid) from public, anon, authenticated;
grant execute on function public.account_storage_objects(uuid) to service_role;

comment on function public.account_storage_objects(uuid) is
  'Service role only. Storage files (bucket, path) to remove when the account is deleted.';

notify pgrst, 'reload schema';
