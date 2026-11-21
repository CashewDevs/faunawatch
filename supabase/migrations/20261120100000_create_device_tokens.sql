-- =============================================================================
-- Migration: create_device_tokens
-- Why: Push notifications. The app registers each device's FCM token for the
--      signed-in user; the send-push Edge Function (supabase/functions/
--      send-push) reads them to push a notification when a row is inserted or
--      grouped-refreshed in public.notifications. In-app notifications are
--      unchanged.
--
-- device_tokens: one row per device token.
--   - token is unique: a physical device has one token, and it can move to
--     another account (sign out, sign in as someone else), so registering a
--     token that already exists REASSIGNS it to the caller.
--   - platform: 'android' or 'ios'.
--   - user_id cascades from profiles, so deleting an account removes its
--     tokens.
--
-- Access:
--   - Clients can read and delete only their own rows. They cannot insert or
--     update directly (no grant): they use the two RPCs below, which are
--     security definer so that reassigning a token from another account works
--     (RLS would hide that row from the caller).
--   - register_device_token(p_token, p_platform) upserts on token for
--     auth.uid(). unregister_device_token(p_token) deletes the caller's row
--     only. Both are executable by authenticated only.
--   - The Edge Function uses the service role (bypasses RLS) to read the
--     recipient's tokens and to delete tokens FCM reports as invalid.
--
-- Suspended users: not handled here. Registering is harmless; the Edge
--   function skips suspended recipients (public.is_suspended), the same way
--   chat notifications skip them.
--
-- Apply after 20261120090100_add_like_and_pending_notifications.sql (any time
-- after public.profiles and public.set_updated_at() exist). Re-runnable.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null unique
                check (char_length(token) between 1 and 4096),
  platform    text not null check (platform in ('android', 'ios')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

drop trigger if exists device_tokens_updated_at on public.device_tokens;
create trigger device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- RLS and grants
-- ---------------------------------------------------------------------------

alter table public.device_tokens enable row level security;

-- Read and delete only. Rows are written through the RPCs below.
revoke all on public.device_tokens from anon, authenticated;
grant select, delete on public.device_tokens to authenticated;
grant select, delete on public.device_tokens to service_role;

drop policy if exists "device_tokens_select_own" on public.device_tokens;
create policy "device_tokens_select_own"
  on public.device_tokens
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "device_tokens_delete_own" on public.device_tokens;
create policy "device_tokens_delete_own"
  on public.device_tokens
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- No insert or update policy: tokens are written by register_device_token().


-- ---------------------------------------------------------------------------
-- register_device_token(p_token, p_platform)
-- ---------------------------------------------------------------------------

create or replace function public.register_device_token(
  p_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  if p_token is null or char_length(p_token) not between 1 and 4096 then
    raise exception 'Invalid device token' using errcode = '22023';
  end if;
  if p_platform is null or p_platform not in ('android', 'ios') then
    raise exception 'Invalid platform' using errcode = '22023';
  end if;

  -- A device that signs in as another user moves its token to that user.
  insert into public.device_tokens (user_id, token, platform)
  values (v_uid, p_token, p_platform)
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke execute on function public.register_device_token(text, text)
  from public, anon;
grant execute on function public.register_device_token(text, text)
  to authenticated;


-- ---------------------------------------------------------------------------
-- unregister_device_token(p_token)
-- ---------------------------------------------------------------------------

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  -- Only the caller's own row; someone else's token is left alone.
  delete from public.device_tokens
  where token = p_token and user_id = v_uid;
end;
$$;

revoke execute on function public.unregister_device_token(text)
  from public, anon;
grant execute on function public.unregister_device_token(text)
  to authenticated;
