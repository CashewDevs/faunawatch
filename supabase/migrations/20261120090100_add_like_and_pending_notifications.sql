-- =============================================================================
-- Migration: add_like_and_pending_notifications
-- Why: Two more in-app notifications for a report's owner (the Notifications
--      tab). Still in-app only: push delivery is NOT part of this migration.
--
--   1. Pending. The owner is told when their report enters 'pending':
--        - a new report is inserted with status 'pending', and
--        - the owner resubmits it (changes_requested -> pending, done by
--          resubmit_report()).
--      Type report_status, with report_id, no actor (never an admin). This is
--      the one exception to "the owner's own actions are not notified"
--      (notify_report_status_change() still skips them). Other ways into
--      pending do NOT notify: an admin withdrawing a change request
--      (changes_requested -> pending, made by someone other than the owner)
--      and anything else. notify_report_status_change() itself is untouched.
--
--   2. Likes. When someone other than the owner likes a report
--      (report_likes insert), the owner gets a 'report_like' notification
--      with report_id and actor_id = the liker (profiles are readable by every
--      signed-in user and the liker's name is already shown to the owner in
--      the title, so this reveals nothing new). Likes are grouped per report
--      like chat is per conversation: if the owner already has an UNREAD
--      report_like notification for that report, it is updated (title,
--      actor_id, created_at = now()) instead of a new row being inserted.
--      The title is "<name> liked your report" while there is one like from
--      others, else "<name> and N others liked your report", where N is the
--      number of likes from users other than the owner, minus one. ("1 other"
--      when N is 1.) The body is the user's species, else the category,
--      truncated to 140 characters (the report has no title column). Unlikes
--      and the owner liking their own report create or change nothing.
--
-- Triggers run in the transaction that caused the event, so they are kept
-- simple and never raise for missing data. All functions are security
-- definer with search_path = '' and not executable by clients.
--
-- Changed: notifications_report_ref now also requires report_id for
--   'report_like' (dropped and recreated; existing rows already satisfy it).
-- New: notify_report_pending(), notify_report_like(), their triggers and
--   notifications_unread_like_idx.
-- Apply after 20261120090000_add_report_like_notification_type.sql, which
-- must have completed first (a new enum value cannot be used in the same
-- transaction). Re-runnable. No notifications are created for past events.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- report_id is required for report notifications, including likes
-- ---------------------------------------------------------------------------

alter table public.notifications
  drop constraint if exists notifications_report_ref;

alter table public.notifications
  add constraint notifications_report_ref
  check (
    type not in ('report_status', 'report_comment', 'report_like')
    or report_id is not null
  );

-- Finding the unread like notification of a report to update.
create index if not exists notifications_unread_like_idx
  on public.notifications (user_id, report_id)
  where type = 'report_like' and read_at is null;


-- ---------------------------------------------------------------------------
-- Generator: report enters pending
-- ---------------------------------------------------------------------------

create or replace function public.notify_report_pending()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_title := 'Your report is pending review';
  elsif old.status = 'changes_requested'
        and new.user_id = (select auth.uid()) then
    -- The owner resubmitting. An admin withdrawing the request is not
    -- notified (auth.uid() is the admin).
    v_title := 'Your resubmitted report is pending review';
  else
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body, report_id)
  values (
    new.user_id,
    'report_status',
    v_title,
    'We''ll let you know once it has been reviewed.',
    new.id
  );

  return new;
end;
$$;

revoke execute on function public.notify_report_pending() from public, anon, authenticated;

drop trigger if exists reports_notify_pending_insert on public.reports;
create trigger reports_notify_pending_insert
  after insert on public.reports
  for each row
  when (new.status = 'pending')
  execute function public.notify_report_pending();

drop trigger if exists reports_notify_pending_resubmit on public.reports;
create trigger reports_notify_pending_resubmit
  after update of status on public.reports
  for each row
  when (old.status is distinct from new.status and new.status = 'pending')
  execute function public.notify_report_pending();


-- ---------------------------------------------------------------------------
-- Generator: likes on a report
-- ---------------------------------------------------------------------------

create or replace function public.notify_report_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner   uuid;
  v_species text;
  v_cat     text;
  v_others  integer;
  v_name    text;
  v_title   text;
  v_body    text;
begin
  select r.user_id, nullif(btrim(r.user_species), ''), r.category::text
    into v_owner, v_species, v_cat
    from public.reports r
    where r.id = new.report_id;

  -- Nothing to tell when the report is gone or the owner liked their own.
  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  select count(*) into v_others
    from public.report_likes l
    where l.report_id = new.report_id
      and l.user_id <> v_owner;

  v_name  := public.notification_actor_name(new.user_id);
  v_title := case
    when v_others <= 1 then v_name || ' liked your report'
    when v_others = 2  then v_name || ' and 1 other liked your report'
    else v_name || ' and ' || (v_others - 1)::text || ' others liked your report'
  end;
  v_body := left(coalesce(v_species, initcap(replace(v_cat, '_', ' ')), ''), 140);

  -- Fold into the newest unread like notification of this report.
  update public.notifications n
     set title      = v_title,
         body       = v_body,
         actor_id   = new.user_id,
         created_at = now()
   where n.id = (
     select u.id
       from public.notifications u
      where u.user_id = v_owner
        and u.type = 'report_like'
        and u.report_id = new.report_id
        and u.read_at is null
      order by u.created_at desc, u.id desc
      limit 1
   );

  if not found then
    insert into public.notifications (user_id, type, title, body, report_id, actor_id)
    values (v_owner, 'report_like', v_title, v_body, new.report_id, new.user_id);
  end if;

  return new;
end;
$$;

revoke execute on function public.notify_report_like() from public, anon, authenticated;

drop trigger if exists report_likes_notify_owner on public.report_likes;
create trigger report_likes_notify_owner
  after insert on public.report_likes
  for each row execute function public.notify_report_like();

