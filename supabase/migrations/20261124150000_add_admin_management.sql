-- =============================================================================
-- Admin management: list admins, remove an admin, and the helpers the Edge
-- Function manage-admins uses to invite, re-invite and cancel invitations.
--
-- * An admin is a row in public.admin_users. "Active" once they have
--   accepted the invitation (or signed in); "invited" until then.
-- * Removing an active admin only takes away admin access: the account and
--   its name on past decisions stay. public.former_admins remembers them, so
--   inviting the same email later gives access back without a new account.
-- * Nobody removes themselves, and the last active admin can't be removed,
--   so the admin site can never be left without an admin.
-- * Invitations need Supabase's Auth admin API (service role), so they are
--   sent by the Edge Function; the functions below marked "service_role
--   only" are its database side and can't be called from a browser.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- former_admins
-- ---------------------------------------------------------------------------

create table if not exists public.former_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  removed_at timestamptz not null default now(),
  removed_by uuid references auth.users (id) on delete set null
);

comment on table public.former_admins is
  'Accounts that were admins and were removed. Inviting the email again '
  'restores admin access. No client policies, like admin_users.';

alter table public.former_admins enable row level security;
-- Intentionally no client policies.
revoke all on public.former_admins from anon, authenticated;


-- ---------------------------------------------------------------------------
-- admin_is_active(): has this admin accepted the invitation?
-- ---------------------------------------------------------------------------

create or replace function public.admin_is_active(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = p_user_id
      and (u.email_confirmed_at is not null or u.last_sign_in_at is not null)
  );
$$;

revoke execute on function public.admin_is_active(uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- admin_list_admins(): every admin, for the admin site's Admins page
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_admins()
returns table (
  user_id      uuid,
  email        text,
  display_name text,
  status       text,        -- 'active' | 'invited'
  invited_at   timestamptz, -- when the latest invitation was sent
  last_sign_in_at timestamptz,
  added_at     timestamptz,
  is_you       boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Only admins can see the admins'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  select
    a.user_id,
    u.email::text,
    coalesce(
      nullif(trim(p.full_name), ''),
      nullif(trim(p.display_name), ''),
      nullif(trim(p.username), '')
    ),
    case when public.admin_is_active(a.user_id) then 'active' else 'invited' end,
    u.invited_at,
    u.last_sign_in_at,
    a.created_at,
    a.user_id = (select auth.uid())
  from public.admin_users a
  join auth.users u on u.id = a.user_id
  left join public.profiles p on p.id = a.user_id
  order by
    public.admin_is_active(a.user_id) desc,
    lower(u.email);
end;
$$;

revoke execute on function public.admin_list_admins() from public, anon;
grant  execute on function public.admin_list_admins() to authenticated;


-- ---------------------------------------------------------------------------
-- admin_remove_admin(): take away an active admin's access
-- ---------------------------------------------------------------------------

create or replace function public.admin_remove_admin(p_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
begin
  if not public.is_admin() then
    raise exception 'Only admins can remove admins'
      using errcode = 'insufficient_privilege';
  end if;

  if p_user_id is null then
    raise exception 'Choose an admin'
      using errcode = 'invalid_parameter_value';
  end if;

  -- One removal at a time, so two admins can't remove each other at once
  -- and leave nobody.
  lock table public.admin_users in share row exclusive mode;

  if not exists (select 1 from public.admin_users a where a.user_id = p_user_id) then
    raise exception 'not_an_admin'
      using errcode = 'FW404', detail = p_user_id::text;
  end if;

  if p_user_id = v_caller then
    raise exception 'cannot_remove_yourself'
      using errcode = 'FW403', detail = p_user_id::text;
  end if;

  -- An invitation is cancelled instead (the Edge Function deletes the
  -- unused account).
  if not public.admin_is_active(p_user_id) then
    raise exception 'invite_pending'
      using errcode = 'FW409', detail = p_user_id::text;
  end if;

  if not exists (
    select 1 from public.admin_users a
    where a.user_id <> p_user_id and public.admin_is_active(a.user_id)
  ) then
    raise exception 'last_admin'
      using errcode = 'FW409', detail = p_user_id::text;
  end if;

  delete from public.admin_users where user_id = p_user_id;

  insert into public.former_admins (user_id, removed_at, removed_by)
  values (p_user_id, now(), v_caller)
  on conflict (user_id) do update
    set removed_at = excluded.removed_at, removed_by = excluded.removed_by;
end;
$$;

revoke execute on function public.admin_remove_admin(uuid) from public, anon;
grant  execute on function public.admin_remove_admin(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_account_status(): what an email or account is (service_role only)
-- ---------------------------------------------------------------------------

-- Returns no row when no account uses the email. status:
--   'admin'        an active admin
--   'invited'      an admin who hasn't accepted the invitation yet
--   'former_admin' removed earlier; inviting again restores access
--   'account'      any other account (an app user): never made an admin
create or replace function public.admin_account_status(
  p_email   text default null,
  p_user_id uuid default null
)
returns table (user_id uuid, email text, status text)
language sql
stable
security definer
set search_path = ''
as $$
  select
    u.id,
    u.email::text,
    case
      when exists (select 1 from public.admin_users a where a.user_id = u.id)
        then case when public.admin_is_active(u.id) then 'admin' else 'invited' end
      when exists (select 1 from public.former_admins f where f.user_id = u.id)
        then 'former_admin'
      else 'account'
    end
  from auth.users u
  where (p_email is not null and lower(u.email) = lower(trim(p_email)))
     or (p_user_id is not null and u.id = p_user_id)
  limit 1;
$$;

revoke execute on function public.admin_account_status(text, uuid) from public, anon, authenticated;
grant  execute on function public.admin_account_status(text, uuid) to service_role;


-- ---------------------------------------------------------------------------
-- admin_grant_access(): make an account an admin (service_role only)
-- ---------------------------------------------------------------------------

-- For a newly invited account, or a former admin invited again.
create or replace function public.admin_grant_access(p_user_id uuid)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.admin_users (user_id) values (p_user_id)
  on conflict (user_id) do nothing;
  delete from public.former_admins where user_id = p_user_id;
$$;

revoke execute on function public.admin_grant_access(uuid) from public, anon, authenticated;
grant  execute on function public.admin_grant_access(uuid) to service_role;
