-- Private one-to-one chats, per-user inbox state, and participant-only photos.
-- All writes go through checked RPCs; clients cannot forge membership/senders.
begin;
create table public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint chat_pair_order check (user_low < user_high),
  unique (user_low, user_high)
);
create index chat_threads_user_high_idx on public.chat_threads(user_high);

create table public.chat_participants (
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz,
  force_unread boolean not null default false,
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (thread_id, user_id)
);
create index chat_participants_user_idx on public.chat_participants(user_id, updated_at desc);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  image_path text unique,
  created_at timestamptz not null default clock_timestamp(),
  constraint chat_body_length check (char_length(body) <= 4000),
  constraint chat_message_content check (btrim(body) <> '' or image_path is not null)
);
create index chat_messages_thread_time_idx on public.chat_messages(thread_id, created_at desc, id desc);
create index chat_messages_sender_idx on public.chat_messages(sender_id);

create function public.is_chat_participant(p_thread_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.chat_threads
    where id = p_thread_id and auth.uid() in (user_low, user_high));
$$;
revoke all on function public.is_chat_participant(uuid) from public, anon;
grant execute on function public.is_chat_participant(uuid) to authenticated;

alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;
revoke all on public.chat_threads, public.chat_participants, public.chat_messages from anon, authenticated;
grant select on public.chat_threads, public.chat_participants, public.chat_messages to authenticated;
create policy chat_threads_select on public.chat_threads for select to authenticated
  using ((select auth.uid()) in (user_low, user_high));
create policy chat_participants_select on public.chat_participants for select to authenticated
  using (user_id = (select auth.uid()));
create policy chat_messages_select on public.chat_messages for select to authenticated
  using (public.is_chat_participant(thread_id));

create function public.open_chat(p_other_user_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_thread uuid;
begin
  if v_uid is null or v_uid = p_other_user_id then
    raise exception 'Choose another registered user.';
  end if;
  if public.is_suspended(v_uid) then raise exception 'Messaging is unavailable while suspended.'; end if;
  insert into public.chat_threads(user_low, user_high)
    values (least(v_uid, p_other_user_id), greatest(v_uid, p_other_user_id))
    on conflict (user_low, user_high) do update set user_low = excluded.user_low
    returning id into v_thread;
  insert into public.chat_participants(thread_id, user_id)
    values (v_thread, v_uid), (v_thread, p_other_user_id) on conflict do nothing;
  -- Reopening restores only the caller's inbox entry.
  update public.chat_participants set hidden_at = null, updated_at = clock_timestamp()
    where thread_id = v_thread and user_id = v_uid;
  return v_thread;
end;
$$;

create function public.list_chat_threads()
returns table (
  id uuid, other_user_id uuid, sender_name text, avatar_path text,
  last_message text, last_message_at timestamptz, unread_count bigint, is_unread boolean
) language sql stable security definer set search_path = '' as $$
  select t.id, p.id,
    coalesce(nullif(p.username, ''), nullif(p.full_name, ''), nullif(p.display_name, ''), 'FaunaWatch user'),
    p.avatar_path, coalesce(nullif(m.body, ''), case when m.image_path is not null then 'Photo' else '' end),
    coalesce(m.created_at, t.created_at), u.n, (s.force_unread or u.n > 0)
  from public.chat_participants s
  join public.chat_threads t on t.id = s.thread_id
  join public.profiles p on p.id = case when t.user_low = auth.uid() then t.user_high else t.user_low end
  left join lateral (select cm.body, cm.image_path, cm.created_at from public.chat_messages cm
    where cm.thread_id = t.id order by cm.created_at desc, cm.id desc limit 1) m on true
  cross join lateral (select count(*) n from public.chat_messages cm
    where cm.thread_id = t.id and cm.sender_id <> auth.uid()
      and (s.last_read_at is null or cm.created_at > s.last_read_at)) u
  where s.user_id = auth.uid() and s.hidden_at is null
  order by coalesce(m.created_at, t.created_at) desc, t.id;
$$;

create function public.set_chat_inbox_state(p_thread_id uuid, p_action text, p_read_message_id uuid default null)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_read_at timestamptz;
begin
  -- Serialize sends and inbox updates, including messages created concurrently.
  perform 1 from public.chat_threads where id = p_thread_id for update;
  if not public.is_chat_participant(p_thread_id) then raise exception 'Conversation unavailable.'; end if;
  if p_action = 'read' then
    select max(created_at) into v_read_at from public.chat_messages
      where thread_id = p_thread_id and (p_read_message_id is null or id = p_read_message_id);
    if p_read_message_id is not null and v_read_at is null then raise exception 'Message unavailable.'; end if;
    update public.chat_participants set
      last_read_at = greatest(last_read_at, v_read_at), force_unread = false, updated_at = clock_timestamp()
      where thread_id = p_thread_id and user_id = auth.uid();
  elsif p_action = 'unread' then
    update public.chat_participants set force_unread = true, updated_at = clock_timestamp()
      where thread_id = p_thread_id and user_id = auth.uid();
  elsif p_action = 'hide' then
    update public.chat_participants set hidden_at = clock_timestamp(), updated_at = clock_timestamp()
      where thread_id = p_thread_id and user_id = auth.uid();
  else raise exception 'Invalid inbox action.';
  end if;
  return true;
end;
$$;

create function public.send_chat_message(p_thread_id uuid, p_body text, p_message_id uuid, p_image_path text default null)
returns public.chat_messages language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_message public.chat_messages;
begin
  perform 1 from public.chat_threads where id = p_thread_id for update;
  if not public.is_chat_participant(p_thread_id) then raise exception 'Conversation unavailable.'; end if;
  if public.is_suspended(v_uid) then raise exception 'Messaging is unavailable while suspended.'; end if;
  if p_image_path is not null and (
    p_image_path not like v_uid::text || '/' || p_thread_id::text || '/%'
    or not exists (select 1 from storage.objects where bucket_id = 'chat-images' and name = p_image_path)
  ) then raise exception 'Photo unavailable.'; end if;
  select * into v_message from public.chat_messages where id = p_message_id;
  if found then
    if v_message.thread_id <> p_thread_id or v_message.sender_id <> v_uid
      or v_message.body <> btrim(p_body) or v_message.image_path is distinct from p_image_path
    then raise exception 'Message unavailable.'; end if;
    return v_message;
  end if;
  insert into public.chat_messages(id, thread_id, sender_id, body, image_path)
    values (p_message_id, p_thread_id, v_uid, btrim(p_body), p_image_path) returning * into v_message;
  -- New messages restore hidden conversations, without removing either user's history.
  update public.chat_participants set hidden_at = null, updated_at = clock_timestamp()
    where thread_id = p_thread_id;
  return v_message;
end;
$$;

revoke all on function public.open_chat(uuid) from public, anon;
revoke all on function public.list_chat_threads() from public, anon;
revoke all on function public.set_chat_inbox_state(uuid, text, uuid) from public, anon;
revoke all on function public.send_chat_message(uuid, text, uuid, text) from public, anon;
grant execute on function public.open_chat(uuid) to authenticated;
grant execute on function public.list_chat_threads() to authenticated;
grant execute on function public.set_chat_inbox_state(uuid, text, uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text, uuid, text) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('chat-images', 'chat-images', false, 5242880, array['image/webp'])
on conflict (id) do nothing;

-- Compare paths as text, avoiding unsafe casts on arbitrary object names.
create function public.can_upload_chat_photo(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(p_path, '/', 1) = auth.uid()::text
    and not public.is_suspended(auth.uid())
    and exists (select 1 from public.chat_threads t
      where t.id::text = split_part(p_path, '/', 2) and auth.uid() in (t.user_low, t.user_high));
$$;
create function public.can_read_chat_photo(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.chat_messages m
    where m.image_path = p_path and public.is_chat_participant(m.thread_id));
$$;
create function public.can_delete_chat_photo(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select split_part(p_path, '/', 1) = auth.uid()::text
    and not exists (select 1 from public.chat_messages where image_path = p_path);
$$;
revoke all on function public.can_upload_chat_photo(text), public.can_read_chat_photo(text), public.can_delete_chat_photo(text) from public, anon;
grant execute on function public.can_upload_chat_photo(text), public.can_read_chat_photo(text), public.can_delete_chat_photo(text) to authenticated;
create policy chat_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-images' and public.can_upload_chat_photo(name));
create policy chat_images_select on storage.objects for select to authenticated
  using (bucket_id = 'chat-images' and (public.can_read_chat_photo(name) or public.can_delete_chat_photo(name)));
create policy chat_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'chat-images' and public.can_delete_chat_photo(name));
-- No UPDATE policy: an attachment cannot be overwritten after sharing.

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.chat_messages, public.chat_participants;
  end if;
end $$;
commit;
