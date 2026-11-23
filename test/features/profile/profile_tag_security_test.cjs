// Local PostgreSQL only; uses the same ignored PGlite runtime as public galleries.
// node test/features/profile/profile_tag_security_test.cjs [pglite-module-path]
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require(path.resolve(process.argv[2] ||
  '.dart_tool/public-profile-sql/node_modules/@electric-sql/pglite'));
const db = new PGlite();
const owner = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';
const migration = fs.readFileSync(
  'supabase/migrations/20261123170000_add_profile_tags.sql', 'utf8');
const cleanup = fs.readFileSync(
  'supabase/migrations/20261124090000_remove_profile_tag_activity.sql', 'utf8');

(async () => {
  try {
    await db.exec(`
      create role anon; create role authenticated;
      create schema auth;
      create function auth.uid() returns uuid language sql stable as
        $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      grant usage on schema auth, public to anon, authenticated;
      create table public.profiles (id uuid primary key);
      create table public.reports (
        id uuid primary key, user_id uuid, status text, user_species text
      );
      create table public.ai_analyses (
        id uuid primary key, report_id uuid, status text,
        possible_species jsonb, created_at timestamptz
      );
      alter table public.profiles enable row level security;
      alter table public.reports enable row level security;
      alter table public.ai_analyses enable row level security;
      grant select, update on public.profiles to authenticated;
      grant select on public.reports, public.ai_analyses to authenticated;
      create policy profile_read on public.profiles for select to authenticated using (true);
      create policy profile_update on public.profiles for update to authenticated
        using (id = auth.uid() and
          coalesce(current_setting('test.suspended', true), 'false') <> 'true')
        with check (id = auth.uid());
      create policy own_reports on public.reports for select to authenticated
        using (user_id = auth.uid());
      create policy own_analysis on public.ai_analyses for select to authenticated
        using (exists(select 1 from public.reports r where r.id = report_id));
      insert into public.profiles values ('${owner}'), ('${other}');
    `);
    await db.exec(migration);
    await db.exec(migration);

    await db.query('update public.profiles set profile_tag = $1 where id = $2',
      ['cat_lover', owner]);
    await db.exec(cleanup);
    await db.exec(cleanup);
    assert.equal((await db.query(
      "select to_regprocedure('public.my_profile_tag_activity()') as function"
    )).rows[0].function, null);
    assert.equal((await db.query(
      "select relrowsecurity from pg_class where oid = 'public.profiles'::regclass"
    )).rows[0].relrowsecurity, true);
    assert.deepEqual((await db.query(
      'select profile_tag from public.profiles where id = $1', [owner]
    )).rows, [{ profile_tag: 'cat_lover' }]);

    await db.exec('set role anon');
    await assert.rejects(db.query(
      'update public.profiles set profile_tag = $1 where id = $2',
      ['dog_lover', owner]), /permission denied/);
    await db.exec(`reset role; set role authenticated;
      set request.jwt.claim.sub = '${owner}'`);
    assert.equal((await db.query('select * from public.reports')).rows.length, 0);

    for (const tag of ['dog_lover', 'cat_lover', 'spotter', null]) {
      const saved = await db.query('update public.profiles set profile_tag = $1 where id = $2 returning profile_tag',
        [tag, owner]);
      assert.deepEqual(saved.rows, [{ profile_tag: tag }]);
    }
    await assert.rejects(
      db.query('update public.profiles set profile_tag = $1 where id = $2', ['admin', owner]),
      (error) => error.code === '23514' && /profiles_profile_tag_check/.test(error.message));
    const notMine = await db.query('update public.profiles set profile_tag = $1 where id = $2 returning id',
      ['dog_lover', other]);
    assert.equal(notMine.rows.length, 0);
    await db.query('update public.profiles set profile_tag = $1 where id = $2',
      ['cat_lover', owner]);
    await db.exec("set test.suspended = 'true'");
    for (const tag of ['dog_lover', null]) {
      assert.equal((await db.query('update public.profiles set profile_tag = $1 where id = $2 returning id',
        [tag, owner])).rows.length, 0);
    }
    assert.deepEqual((await db.query(
      'select profile_tag from public.profiles where id = $1', [owner]
    )).rows, [{ profile_tag: 'cat_lover' }]);
    await db.exec("set test.suspended = 'false'");

    await db.exec(`set request.jwt.claim.sub = '${other}'`);
    assert.equal((await db.query(
      'update public.profiles set profile_tag = $1 where id = $2 returning id',
      ['spotter', owner])).rows.length, 0);
    await db.exec("set request.jwt.claim.sub = ''");
    assert.equal((await db.query(
      'update public.profiles set profile_tag = $1 where id = $2 returning id',
      ['spotter', owner])).rows.length, 0);
    console.log('Profile tag SQL: cleanup idempotence, free choice without reports, preserved tags, account isolation and RLS checks passed.');
  } finally {
    await db.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
