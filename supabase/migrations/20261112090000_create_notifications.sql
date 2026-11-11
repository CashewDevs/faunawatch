-- =============================================================================
-- Migration: create_notifications
-- Why: In-app notifications (the Notifications tab). Replaces the app's
--      hard-coded sample list. In-app only: push delivery (FCM, device
--      tokens, an Edge Function) is NOT part of this migration and needs
--      its own approval.
--
-- notifications: one row per notification, owned by the recipient.
--   - type notification_type:
--       report_status   the owner's report was approved, declined (or taken
--                       down) or sent back for changes
--       report_comment  someone commented on the owner's report
--       chat_message    a new private chat message (see "Chat" below)
--       nearby_alert    nearby sighting/warning. NOT GENERATED YET, see the
--                       open question at the end of this file.
--   - report_id / thread_id: what the notification is about, so the app can
--     open it. Both cascade, so deleting a report or chat removes them.
--   - actor_id: who caused it, only when that person is already visible to
--     the recipient:
--       report_comment  the commenter. report_comments.user_id is readable by
--                       anyone who can read the comment and profiles are
--                       readable by every signed-in user, so this reveals
--                       nothing new.
--       chat_message    the sender (chat shows both participants by name).
--       report_status   always null. Reporters must not learn which admin
--                       decided (same rule as report_change_requests).
--     The name is also copied into the title when the row is made.
--   - read_at: null = unread.
--
-- Access:
--   - Clients can select and delete their own rows and update ONLY read_at
--     (mark read / unread / all read), enforced by a column-level grant plus
--     an own-row RLS policy. There is no insert policy or grant: rows come
--     only from the security definer trigger functions below.
--   - The generators run inside the transaction that caused the event, so a
--     failure in them would roll that event back. They are kept simple and
--     never raise for missing data.
--
-- Generators (all security definer, set search_path = ''):
--   Report status  after reports.status changes to approved, declined or
--                  changes_requested, the owner is notified. Not for
--                  pending (resubmit/withdraw) and not when the owner made
--                  the change themselves. A decline carries the reason from
--                  the report_reviews row written just before it; a
--                  take-down (approved -> declined) is worded as such. A
--                  change request carries the admin's message, which the
--                  owner can already read through my_report_change_requests().
--                  Admin notes are never included.
--   Comments       after a report_comments insert, the report owner is
--                  notified unless they wrote the comment. Only approved
--                  reports accept comments, so the owner can see it.
--   Chat           after a chat_messages insert, the other participant is
--                  notified, unless they are suspended (suspended users
--                  cannot open chats). To avoid one row per message, an
--                  existing UNREAD chat_message notification for the same
--                  conversation is updated with the latest sender, text and
--                  time instead. Photos never expose a storage path: a
--                  photo without text reads "Sent a photo". send_chat_message()
--                  locks the thread row, so concurrent sends can't create
--                  duplicates (hence no unique index, which would break
--                  "mark as unread" on an older notification).
--
-- Realtime: notifications is added to supabase_realtime like the chat tables.
--
-- New: notification_type, notifications, notification_actor_name(),
--   notify_report_status_change(), notify_report_comment(),
--   notify_chat_message() and their triggers.
-- Changed: nothing existing. alerts is untouched.
-- Apply after 20261111150721_add_report_change_requests.sql. Existing rows
-- are not touched and no notifications are created for past events.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- notification_type
-- ---------------------------------------------------------------------------

-- Created with all its values at once, so it can be used in this migration.
create type public.notification_type as enum (
  'report_status',
  'report_comment',
  'chat_message',
  'nearby_alert'
);


-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),

  -- Recipient.
  user_id     uuid not null references public.profiles (id) on delete cascade,

  type        public.notification_type not null,
  title       text not null check (char_length(title) between 1 and 200),
  body        text not null default '' check (char_length(body) <= 1000),

  report_id   uuid references public.reports (id) on delete cascade,
  thread_id   uuid references public.chat_threads (id) on delete cascade,

  -- See the header: null for report_status, never an admin.
  actor_id    uuid references public.profiles (id) on delete set null,

  -- null = unread
  read_at     timestamptz,

  created_at  timestamptz not null default now(),

  constraint notifications_report_ref
    check (type not in ('report_status', 'report_comment') or report_id is not null),
  constraint notifications_thread_ref
    check (type <> 'chat_message' or thread_id is not null)
);

comment on table public.notifications is
  'In-app notifications. System-generated by triggers; clients can only read, '
  'delete and set read_at on their own rows. No push delivery yet.';

comment on column public.notifications.actor_id is
  'Commenter or chat sender, who the recipient can already see. Always null '
  'for report_status so the deciding admin stays hidden.';

-- Per-user listing, newest first (keyset paging on created_at, id).
create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc, id desc);

-- Unread badge/count.
create index if not exists notifications_user_unread_idx
  on public.notifications (user_id)
  where read_at is null;

-- Finding the unread chat notification of a conversation to update.
create index if not exists notifications_unread_chat_idx
  on public.notifications (user_id, thread_id)
  where type = 'chat_message' and read_at is null;

-- Foreign key indexes.
create index if not exists notifications_report_id_idx
  on public.notifications (report_id);

create index if not exists notifications_thread_id_idx
  on public.notifications (thread_id);

create index if not exists notifications_actor_id_idx
  on public.notifications (actor_id);


-- ---------------------------------------------------------------------------
-- RLS and grants
-- ---------------------------------------------------------------------------

alter table public.notifications enable row level security;

-- Column-level grant: the only column a client can change is read_at, so
-- title, body, type and the rest stay exactly as the triggers wrote them.
-- Security definer functions run as the table owner and are not limited by
-- this. No insert grant: clients can't create notifications.
revoke all on public.notifications from anon, authenticated;
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
  on public.notifications
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
  on public.notifications
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
  on public.notifications
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- No insert policy: notifications are system-generated.


-- ---------------------------------------------------------------------------
-- Display name used in titles (internal)
-- ---------------------------------------------------------------------------

-- Same fallbacks as list_chat_threads(). Called only by the trigger
-- functions below; not executable by clients.
create or replace function public.notification_actor_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select left(
    coalesce(
      (select coalesce(nullif(p.username, ''), nullif(p.full_name, ''), nullif(p.display_name, ''))
         from public.profiles p
        where p.id = p_user_id),
      'FaunaWatch user'
    ),
    60
  );
$$;

revoke execute on function public.notification_actor_name(uuid) from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- Generator: report status changes
-- ---------------------------------------------------------------------------

create or replace function public.notify_report_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title   text;
  v_body    text;
  v_reason  text;
  v_message text;
begin
  if new.status not in ('approved', 'declined', 'changes_requested') then
    return new;
  end if;

  -- The owner already knows about their own actions.
  if new.user_id = (select auth.uid()) then
    return new;
  end if;

  if new.status = 'approved' then
    v_title := 'Your report was approved';
    v_body  := 'It is now visible to the community.';

  elsif new.status = 'declined' then
    -- admin_decide_report() / admin_take_down_report() write the review row
    -- just before changing the status, in the same transaction.
    select rr.decline_reason::text into v_reason
      from public.report_reviews rr
      where rr.report_id = new.id
        and rr.decision = 'declined'
      order by rr.decided_at desc
      limit 1;

    v_title := case when old.status = 'approved'
                    then 'Your report was taken down'
                    else 'Your report was declined' end;
    v_body  := case
      when v_reason is null then 'Open the report for details.'
      else 'Reason: ' || case v_reason
        when 'inaccurate_species'    then 'inaccurate species'
        when 'low_quality_photo'     then 'low-quality photo'
        when 'domestic_specimen'     then 'domestic specimen'
        when 'duplicate'             then 'duplicate report'
        when 'inaccurate_gps'        then 'inaccurate GPS location'
        when 'inappropriate_content' then 'inappropriate content'
        when 'not_wildlife'          then 'not about wildlife'
        else replace(v_reason, '_', ' ')
      end || '.'
    end;

  else
    -- changes_requested: the request row is written before the status change.
    select cr.message into v_message
      from public.report_change_requests cr
      where cr.report_id = new.id
        and cr.resolution is null
      order by cr.round desc
      limit 1;

    v_title := 'Changes requested on your report';
    v_body  := coalesce(v_message, 'Open the report to see what to update.');
  end if;

  insert into public.notifications (user_id, type, title, body, report_id)
  values (new.user_id, 'report_status', v_title, v_body, new.id);

  return new;
end;
$$;

revoke execute on function public.notify_report_status_change() from public, anon, authenticated;

drop trigger if exists reports_notify_status_change on public.reports;
create trigger reports_notify_status_change
  after update of status on public.reports
  for each row
  when (old.status is distinct from new.status)
  execute function public.notify_report_status_change();


-- ---------------------------------------------------------------------------
-- Generator: comments on a report
-- ---------------------------------------------------------------------------

create or replace function public.notify_report_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  select r.user_id into v_owner
    from public.reports r
    where r.id = new.report_id;

  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body, report_id, actor_id)
  values (
    v_owner,
    'report_comment',
    public.notification_actor_name(new.user_id) || ' commented on your report',
    left(btrim(new.body), 140),
    new.report_id,
    new.user_id
  );

  return new;
end;
$$;

revoke execute on function public.notify_report_comment() from public, anon, authenticated;

drop trigger if exists report_comments_notify_owner on public.report_comments;
create trigger report_comments_notify_owner
  after insert on public.report_comments
  for each row execute function public.notify_report_comment();


-- ---------------------------------------------------------------------------
-- Generator: new chat messages
-- ---------------------------------------------------------------------------

create or replace function public.notify_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient uuid;
  v_title     text;
  v_body      text;
begin
  select case when t.user_low = new.sender_id then t.user_high else t.user_low end
    into v_recipient
    from public.chat_threads t
    where t.id = new.thread_id;

  if v_recipient is null or v_recipient = new.sender_id then
    return new;
  end if;

  -- Suspended users cannot open chats, so there is nothing to open.
  if public.is_suspended(v_recipient) then
    return new;
  end if;

  v_title := public.notification_actor_name(new.sender_id);
  -- Never the photo's storage path.
  v_body  := case when btrim(new.body) <> ''
                  then left(btrim(new.body), 140)
                  else 'Sent a photo' end;

  -- Fold into the newest unread notification of this conversation.
  update public.notifications n
     set title      = v_title,
         body       = v_body,
         actor_id   = new.sender_id,
         created_at = now()
   where n.id = (
     select u.id
       from public.notifications u
      where u.user_id = v_recipient
        and u.type = 'chat_message'
        and u.thread_id = new.thread_id
        and u.read_at is null
      order by u.created_at desc, u.id desc
      limit 1
   );

  if not found then
    insert into public.notifications (user_id, type, title, body, thread_id, actor_id)
    values (v_recipient, 'chat_message', v_title, v_body, new.thread_id, new.sender_id);
  end if;

  return new;
end;
$$;

revoke execute on function public.notify_chat_message() from public, anon, authenticated;

drop trigger if exists chat_messages_notify_recipient on public.chat_messages;
create trigger chat_messages_notify_recipient
  after insert on public.chat_messages
  for each row execute function public.notify_chat_message();


-- ---------------------------------------------------------------------------
-- Nearby alerts: type only, no generator
-- ---------------------------------------------------------------------------

-- 'nearby_alert' exists so the app can already render it.
-- TODO(open question): nothing creates nearby_alert rows yet. Generation needs
--   (1) the Approaching / Near / Danger Zone radius values that
--   warning_zones leaves open (they must not be hardcoded), and (2) a decided
--   generation path (database trigger on approval, scheduled job, Edge
--   Function or client-side), plus how a user's own location is known to the
--   server. alerts (report_id + warning_level) stays as it is; decide with
--   this whether it is kept, folded into notifications, or dropped.


-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
