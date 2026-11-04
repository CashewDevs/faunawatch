// Run: node test/features/messages/chat_security_test.cjs <path-to-pglite-module>
// Uses an isolated, in-memory PostgreSQL with minimal Supabase auth/storage
// fixtures. Never connects to a hosted project. Realtime delivery is not mocked
// as proven here: it still needs a two-device Supabase smoke test after setup.
const { PGlite } = require(process.argv[2] || '@electric-sql/pglite');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const db = new PGlite();
const a = '00000000-0000-4000-8000-000000000001';
const b = '00000000-0000-4000-8000-000000000002';
const c = '00000000-0000-4000-8000-000000000003';
const m1 = '10000000-0000-4000-8000-000000000001';
const m2 = '10000000-0000-4000-8000-000000000002';
const m3 = '10000000-0000-4000-8000-000000000003';
const scalar = async (sql) => Object.values((await db.query(sql)).rows[0])[0];
const asUser = async (id) => db.exec(`reset role; set role authenticated; set request.jwt.claim.sub = '${id}';`);

(async () => {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema storage;
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    create table public.profiles(id uuid primary key, username text, full_name text, display_name text, avatar_path text);
    create table public.test_suspensions(user_id uuid);
    create function public.is_suspended(p_uid uuid) returns boolean language sql security definer as
      $$ select exists(select 1 from public.test_suspensions where user_id = p_uid) $$;
    create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text, name text);
    alter table storage.objects enable row level security;
    grant usage on schema auth, storage, public to authenticated, anon;
    grant select, insert, delete, update on storage.objects to authenticated;
    insert into public.profiles(id, username) values ('${a}', 'alice'), ('${b}', 'bob'), ('${c}', 'charlie');
  `);
  await db.exec(fs.readFileSync('supabase/migrations/20261104133813_create_private_chats.sql', 'utf8'));
  await asUser(a);
  const thread = await scalar(`select public.open_chat('${b}')`);
  assert.equal(await scalar(`select public.open_chat('${b}')`), thread);
  await assert.rejects(db.query(`select public.open_chat('${a}')`), /another registered user/);
  await db.query(`select public.send_chat_message('${thread}', 'hello', '${m1}')`);
  await db.query(`select public.send_chat_message('${thread}', 'hello', '${m1}')`);
  assert.equal(await scalar(`select count(*) from public.chat_messages`), 1, 'idempotent sends');
  await assert.rejects(db.query(`insert into public.chat_messages(thread_id, sender_id, body) values ('${thread}', '${b}', 'forged')`), /permission denied/);
  await assert.rejects(db.query(`update public.chat_participants set user_id='${c}'`), /permission denied/);
  await assert.rejects(db.query(`select public.send_chat_message('${thread}', '', '${m2}')`), /chat_message_content/);
  await assert.rejects(db.query(`select public.send_chat_message('${thread}', repeat('x',4001), '${m2}')`), /chat_body_length/);
  const photo = `${a}/${thread}/photo.webp`;
  await db.query(`insert into storage.objects(bucket_id, name) values ('chat-images', '${photo}')`);
  await db.query(`select public.send_chat_message('${thread}', '', '${m2}', '${photo}')`);
  assert.equal(await scalar(`select count(*) from storage.objects`), 1);
  assert.equal((await db.query(`delete from storage.objects where name='${photo}' returning id`)).rows.length, 0, 'shared photos cannot be deleted');
  assert.equal((await db.query(`update storage.objects set name='replaced' where name='${photo}' returning id`)).rows.length, 0);
  assert.equal(await scalar(`select name from storage.objects`), photo, 'shared photos cannot be overwritten');
  await asUser(b);
  assert.equal(await scalar(`select public.open_chat('${a}')`), thread, 'reverse pair reuses thread');
  assert.equal(await scalar(`select unread_count from public.list_chat_threads()`), 2);
  await db.query(`select public.set_chat_inbox_state('${thread}', 'read', '${m1}')`);
  assert.equal(await scalar(`select unread_count from public.list_chat_threads()`), 1, 'read only through observed message');
  await db.query(`select public.set_chat_inbox_state('${thread}', 'read', '${m2}')`);
  assert.equal(await scalar(`select is_unread from public.list_chat_threads()`), false);
  await db.query(`select public.set_chat_inbox_state('${thread}', 'unread')`);
  assert.equal(await scalar(`select is_unread from public.list_chat_threads()`), true);
  assert.equal(await scalar(`select count(*) from storage.objects`), 1, 'recipient can read photo');
  await assert.rejects(db.query(`select public.send_chat_message('${thread}', '', '${m3}', '${photo}')`), /Photo unavailable/);
  await db.query(`select public.set_chat_inbox_state('${thread}', 'hide')`);
  assert.equal(await scalar(`select count(*) from public.list_chat_threads()`), 0);
  await asUser(a);
  assert.equal(await scalar(`select count(*) from public.list_chat_threads()`), 1, 'hide affects only caller');
  await db.query(`select public.send_chat_message('${thread}', 'new message', '${m3}')`);
  await asUser(b);
  assert.equal(await scalar(`select count(*) from public.list_chat_threads()`), 1, 'new message restores inbox');
  await asUser(c);
  assert.equal(await scalar(`select count(*) from public.chat_threads`), 0);
  assert.equal(await scalar(`select count(*) from public.chat_messages`), 0);
  assert.equal(await scalar(`select count(*) from public.chat_participants`), 0);
  assert.equal(await scalar(`select count(*) from storage.objects`), 0);
  assert.equal(await scalar(`select count(*) from public.list_chat_threads()`), 0);
  await assert.rejects(db.query(`select public.send_chat_message('${thread}', 'intruder', gen_random_uuid())`), /Conversation unavailable/);
  await assert.rejects(db.query(`select public.set_chat_inbox_state('${thread}', 'hide')`), /Conversation unavailable/);
  await assert.rejects(db.query(`insert into storage.objects(bucket_id,name) values ('chat-images','${c}/${thread}/intruder.webp')`), /row-level security/);
  await db.exec(`reset role; insert into public.test_suspensions values ('${a}');`);
  await asUser(a);
  await assert.rejects(db.query(`select public.send_chat_message('${thread}', 'suspended', gen_random_uuid())`), /suspended/);
  await assert.rejects(db.query(`select public.open_chat('${c}')`), /suspended/);
  await assert.rejects(db.query(`insert into storage.objects(bucket_id,name) values ('chat-images','${a}/${thread}/suspended.webp')`), /row-level security/);
  await db.exec('reset role; set role anon;');
  await assert.rejects(db.query(`select public.list_chat_threads()`), /permission denied/);
  await assert.rejects(db.query(`select * from public.chat_messages`), /permission denied/);
  console.log('Chat migration: schema, RPCs, privacy, inbox state, photos, and suspension checks passed.');
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => db.close());
