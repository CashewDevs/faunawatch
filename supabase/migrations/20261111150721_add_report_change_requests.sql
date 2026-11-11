-- =============================================================================
-- Migration: add_report_change_requests
-- Why: Phase 5 "Request changes" (types added in the previous migration,
--      add_changes_requested_status_and_change_enums).
--
-- Flow:
--   pending --admin_request_changes()--> changes_requested
--   changes_requested --resubmit_report()--> pending        (reporter)
--   changes_requested --admin_withdraw_change_request()--> pending (admin)
-- Only pending posts can be sent back. While a post waits, admins can only
-- withdraw the request: admin_decide_report() still needs pending and
-- admin_take_down_report() still needs approved, so both refuse it.
-- A request is not a decision, so no report_reviews row is written.
-- There is no limit on rounds.
--
-- report_change_requests: one row per request.
--   - round: 1, 2, ... per report. The open request's requested_at is
--     "waiting since".
--   - At most one open (unresolved) request per report (partial unique
--     index).
--   - Written only by the functions below: no insert, update or delete
--     policies, and clients are granted select only (anon nothing), like
--     the chat tables. Admins can read every row (and embed it under
--     reports).
--   - message: 1-500 characters with no leading or trailing whitespace
--     (spaces, tabs, newlines); line breaks inside are kept.
--   - Reporters must not learn which admin sent a request, so they get no
--     select policy here (a policy can only hide rows, not columns, and
--     column grants would hide requested_by from admins too, who use the
--     same database role). They read their requests through
--     my_report_change_requests(), which leaves out requested_by and
--     resolved_by.
--
-- Editing while changes are requested: the owner may edit the report and
-- its photos (reports_update_own, can_edit_report_media) while it is
-- pending, as before, or while changes are requested and they aren't
-- suspended. Pending behaviour is unchanged.
--
-- Resubmitting: resubmit_report() closes the request and moves the post
-- back to pending. If the photos changed since the request, it deletes the
-- report's AI analyses and sets ai_status to 'unavailable' (what the app
-- writes for a post without an analysis), so a fresh analysis can be added
-- while pending. "Photos changed" compares a fingerprint of the report's
-- report_images rows and report-images storage objects taken when the
-- request was made (report_photo_snapshot()) with one taken at resubmit;
-- it catches added, removed and replaced photos, in either place.
--
-- guard_report_status(): status changes were only allowed for admins inside
-- the moderation functions (transaction-local flag
-- faunawatch.deciding_report). It now also allows exactly one owner move,
-- changes_requested -> pending, when all of these hold:
--   - the transaction-local flag faunawatch.resubmitting_report equals this
--     report's id (set only inside resubmit_report()),
--   - the caller owns the report,
--   - the report has no open change request (resubmit_report() closes it
--     first; clients can't write report_change_requests).
-- Clients can't call set_config() through the API (PostgREST only exposes
-- the public schema), and even with the flag the last check stops a direct
-- status update. The guard's error message no longer names one function.
--
-- New: report_change_requests, report_photo_snapshot(),
--   admin_request_changes(), admin_withdraw_change_request(),
--   resubmit_report(), my_report_change_requests().
-- Changed: guard_report_status(), can_edit_report_media(),
--   reports_update_own.
-- Unchanged on purpose: community_reports(), can_view_report_media() and
--   the comment rules all need 'approved', so a post waiting for changes
--   stays off the map, its photos stay owner/admin only and it can't get
--   comments.
--
-- Errors: insufficient_privilege (42501) for non-admins / non-owners,
--   invalid_parameter_value for bad input, FW404 report_not_found,
--   FW409 report_not_pending / report_not_awaiting_changes,
--   FW403 user_suspended (resubmit by a suspended reporter).
-- Existing rows untouched.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_change_requests
-- ---------------------------------------------------------------------------

create table if not exists public.report_change_requests (
  id              uuid primary key default gen_random_uuid(),

  report_id       uuid not null references public.reports (id) on delete cascade,
  round           integer not null check (round >= 1),

  requested_by    uuid references public.profiles (id) on delete set null,
  requested_at    timestamptz not null default now(),

  message         text not null
                  check (char_length(message) between 1 and 500
                         and message = regexp_replace(message, '^\s+|\s+$', '', 'g')),
  fields          public.report_change_field[] not null default '{}'
                  check (array_position(fields, null) is null),

  -- Fingerprint of the report's photos when the request was made. Internal;
  -- compared at resubmit to decide whether the AI analysis is stale.
  photo_snapshot  text not null,

  resolution      public.change_request_resolution,
  resolved_at     timestamptz,
  resolved_by     uuid references public.profiles (id) on delete set null,

  constraint report_change_requests_round_unique unique (report_id, round),
  constraint report_change_requests_resolved_together
    check ((resolution is null) = (resolved_at is null))
);

comment on table public.report_change_requests is
  'Admin requests for the reporter to fix a pending post. One row per round. '
  'At most one open (resolution is null) per report. Written only through '
  'admin_request_changes(), admin_withdraw_change_request() and '
  'resubmit_report(). Admins read all rows; reporters use '
  'my_report_change_requests(), which hides which admin was involved.';

comment on column public.report_change_requests.round is
  'Round number for this report: 1 for the first request, 2 for the next, ...';
comment on column public.report_change_requests.requested_by is
  'Admin who sent the request. Never shown to the reporter.';
comment on column public.report_change_requests.resolved_by is
  'Reporter (resubmitted) or admin (withdrawn). Never shown to the reporter.';
comment on column public.report_change_requests.photo_snapshot is
  'report_photo_snapshot() at request time. Internal.';

create unique index if not exists report_change_requests_one_open_idx
  on public.report_change_requests (report_id)
  where resolution is null;

create index if not exists report_change_requests_requested_by_idx
  on public.report_change_requests (requested_by);

alter table public.report_change_requests enable row level security;

-- Clients only read (rows limited by the policy below); writes go through
-- the security definer functions.
revoke all on public.report_change_requests from anon, authenticated;
grant select on public.report_change_requests to authenticated;

drop policy if exists "report_change_requests_select_admin" on public.report_change_requests;
create policy "report_change_requests_select_admin"
  on public.report_change_requests
  for select
  to authenticated
  using (public.is_admin());


-- ---------------------------------------------------------------------------
-- report_photo_snapshot(): fingerprint of a report's photos (internal)
-- ---------------------------------------------------------------------------

-- Covers report_images rows (id, fingerprint, path) and the report's
-- objects in the report-images bucket (id, name, updated_at, eTag), so a
-- photo added, removed or overwritten in either place changes the result.
-- Only called by the security definer functions below; not executable by
-- clients.
create or replace function public.report_photo_snapshot(p_report_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select md5(
    coalesce((
      select string_agg(
               ri.id::text || ':' || ri.fingerprint || ':' || ri.storage_path,
               ',' order by ri.id)
      from public.report_images ri
      where ri.report_id = p_report_id
    ), '')
    || '|' ||
    coalesce((
      select string_agg(
               o.id::text || ':' || o.name || ':'
                 || coalesce(o.updated_at::text, '') || ':'
                 || coalesce(o.metadata ->> 'eTag', ''),
               ',' order by o.id)
      from storage.objects o
      where o.bucket_id = 'report-images'
        and o.name like p_report_id::text || '/%'
    ), '')
  );
$$;

revoke execute on function public.report_photo_snapshot(uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- guard_report_status(): moderation functions, or the reporter resubmitting
-- ---------------------------------------------------------------------------

create or replace function public.guard_report_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    -- The reporter resubmitting, inside resubmit_report() only.
    if old.status = 'changes_requested'
       and new.status = 'pending'
       and coalesce(current_setting('faunawatch.resubmitting_report', true), '') = old.id::text
       and old.user_id = (select auth.uid())
       and not exists (
         select 1 from public.report_change_requests cr
         where cr.report_id = old.id
           and cr.resolution is null
       )
    then
      return new;
    end if;

    if not public.is_admin() then
      raise exception 'Only admins can change report status';
    end if;
    if coalesce(current_setting('faunawatch.deciding_report', true), '') <> 'on' then
      raise exception 'Report status can only be changed through the moderation functions';
    end if;
  end if;
  return new;
end;
$$;


-- ---------------------------------------------------------------------------
-- Owner editing: pending (unchanged) or changes requested (not suspended)
-- ---------------------------------------------------------------------------

drop policy if exists "reports_update_own" on public.reports;
create policy "reports_update_own"
  on public.reports
  for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    and (
      status = 'pending'
      or (status = 'changes_requested' and not public.is_suspended((select auth.uid())))
    )
  )
  with check (
    (select auth.uid()) = user_id
    and (
      status = 'pending'
      or (status = 'changes_requested' and not public.is_suspended((select auth.uid())))
    )
  );

-- Used by the report_images policies and the report-images storage
-- insert/update/delete policies. Still runs as the caller.
create or replace function public.can_edit_report_media(p_report_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.user_id = (select auth.uid())
      and (
        r.status = 'pending'
        or (r.status = 'changes_requested' and not public.is_suspended((select auth.uid())))
      )
  );
$$;

revoke execute on function public.can_edit_report_media(uuid) from public, anon;
grant  execute on function public.can_edit_report_media(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_request_changes(): pending -> changes_requested
-- ---------------------------------------------------------------------------

create or replace function public.admin_request_changes(
  p_report_id uuid,
  p_message   text,
  p_fields    public.report_change_field[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Leading/trailing whitespace of any kind (spaces, tabs, newlines) is
  -- dropped, so a whitespace-only message counts as empty.
  v_message text := nullif(regexp_replace(p_message, '^\s+|\s+$', '', 'g'), '');
  v_fields  public.report_change_field[];
  v_status  public.report_status;
  v_round   integer;
begin
  if not public.is_admin() then
    raise exception 'Only admins can request changes'
      using errcode = 'insufficient_privilege';
  end if;

  if p_report_id is null then
    raise exception 'Choose a report'
      using errcode = 'invalid_parameter_value';
  end if;

  if v_message is null then
    raise exception 'A message is required to request changes'
      using errcode = 'invalid_parameter_value';
  end if;

  if char_length(v_message) > 500 then
    raise exception 'Message must be at most 500 characters'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Each tick once, in enum order; nulls dropped.
  select coalesce(array_agg(distinct f order by f), '{}')
    into v_fields
    from unnest(coalesce(p_fields, '{}')) as f
    where f is not null;

  select r.status into v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found then
    raise exception 'report_not_found'
      using errcode = 'FW404', detail = p_report_id::text;
  end if;

  if v_status <> 'pending' then
    raise exception 'report_not_pending'
      using errcode = 'FW409', detail = p_report_id::text;
  end if;

  select coalesce(max(cr.round), 0) + 1 into v_round
    from public.report_change_requests cr
    where cr.report_id = p_report_id;

  insert into public.report_change_requests
    (report_id, round, requested_by, message, fields, photo_snapshot)
  values
    (p_report_id, v_round, (select auth.uid()), v_message, v_fields,
     public.report_photo_snapshot(p_report_id));

  perform set_config('faunawatch.deciding_report', 'on', true);

  update public.reports
  set status = 'changes_requested'
  where id = p_report_id;

  perform set_config('faunawatch.deciding_report', '', true);
end;
$$;

revoke execute on function public.admin_request_changes(uuid, text, public.report_change_field[]) from public, anon;
grant  execute on function public.admin_request_changes(uuid, text, public.report_change_field[]) to authenticated;


-- ---------------------------------------------------------------------------
-- admin_withdraw_change_request(): changes_requested -> pending
-- ---------------------------------------------------------------------------

create or replace function public.admin_withdraw_change_request(p_report_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.report_status;
begin
  if not public.is_admin() then
    raise exception 'Only admins can withdraw change requests'
      using errcode = 'insufficient_privilege';
  end if;

  if p_report_id is null then
    raise exception 'Choose a report'
      using errcode = 'invalid_parameter_value';
  end if;

  select r.status into v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found then
    raise exception 'report_not_found'
      using errcode = 'FW404', detail = p_report_id::text;
  end if;

  if v_status <> 'changes_requested' then
    raise exception 'report_not_awaiting_changes'
      using errcode = 'FW409', detail = p_report_id::text;
  end if;

  update public.report_change_requests
  set resolution  = 'withdrawn',
      resolved_at = now(),
      resolved_by = (select auth.uid())
  where report_id = p_report_id
    and resolution is null;

  perform set_config('faunawatch.deciding_report', 'on', true);

  update public.reports
  set status = 'pending'
  where id = p_report_id;

  perform set_config('faunawatch.deciding_report', '', true);
end;
$$;

revoke execute on function public.admin_withdraw_change_request(uuid) from public, anon;
grant  execute on function public.admin_withdraw_change_request(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- resubmit_report(): reporter, changes_requested -> pending
-- ---------------------------------------------------------------------------

-- Returns true when the photos changed since the request, in which case
-- the report's AI analyses were deleted and ai_status is 'unavailable'.
create or replace function public.resubmit_report(p_report_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid            uuid := (select auth.uid());
  v_owner          uuid;
  v_status         public.report_status;
  v_request_id     uuid;
  v_snapshot       text;
  v_photos_changed boolean;
begin
  if p_report_id is null then
    raise exception 'Choose a report'
      using errcode = 'invalid_parameter_value';
  end if;

  select r.user_id, r.status into v_owner, v_status
    from public.reports r
    where r.id = p_report_id
    for update;

  if not found then
    raise exception 'report_not_found'
      using errcode = 'FW404', detail = p_report_id::text;
  end if;

  if v_uid is null or v_owner <> v_uid then
    raise exception 'Only the reporter can resubmit a report'
      using errcode = 'insufficient_privilege';
  end if;

  if public.is_suspended(v_uid) then
    raise exception 'user_suspended'
      using errcode = 'FW403', detail = v_uid::text;
  end if;

  if v_status <> 'changes_requested' then
    raise exception 'report_not_awaiting_changes'
      using errcode = 'FW409', detail = p_report_id::text;
  end if;

  select cr.id, cr.photo_snapshot into v_request_id, v_snapshot
    from public.report_change_requests cr
    where cr.report_id = p_report_id
      and cr.resolution is null
    for update;

  if not found then
    -- changes_requested always has an open request; refuse rather than guess.
    raise exception 'change_request_not_found'
      using errcode = 'FW404', detail = p_report_id::text;
  end if;

  v_photos_changed := v_snapshot is distinct from public.report_photo_snapshot(p_report_id);

  update public.report_change_requests
  set resolution  = 'resubmitted',
      resolved_at = now(),
      resolved_by = v_uid
  where id = v_request_id;

  if v_photos_changed then
    delete from public.ai_analyses where report_id = p_report_id;
  end if;

  -- Let guard_report_status() accept this one owner move.
  perform set_config('faunawatch.resubmitting_report', p_report_id::text, true);

  update public.reports
  set status    = 'pending',
      ai_status = case when v_photos_changed then 'unavailable' else ai_status end
  where id = p_report_id;

  perform set_config('faunawatch.resubmitting_report', '', true);

  return v_photos_changed;
end;
$$;

revoke execute on function public.resubmit_report(uuid) from public, anon;
grant  execute on function public.resubmit_report(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- my_report_change_requests(): the reporter's view, without admin ids
-- ---------------------------------------------------------------------------

-- The caller's own reports only. p_report_id null = all of them.
create or replace function public.my_report_change_requests(p_report_id uuid default null)
returns table (
  id           uuid,
  report_id    uuid,
  round        integer,
  message      text,
  fields       public.report_change_field[],
  requested_at timestamptz,
  resolution   public.change_request_resolution,
  resolved_at  timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    cr.id,
    cr.report_id,
    cr.round,
    cr.message,
    cr.fields,
    cr.requested_at,
    cr.resolution,
    cr.resolved_at
  from public.report_change_requests cr
    join public.reports r on r.id = cr.report_id
  where r.user_id = (select auth.uid())
    and (p_report_id is null or cr.report_id = p_report_id)
  order by cr.report_id, cr.round;
$$;

revoke execute on function public.my_report_change_requests(uuid) from public, anon;
grant  execute on function public.my_report_change_requests(uuid) to authenticated;
