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
const id = (n) => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const migration = fs.readFileSync(
  'supabase/migrations/20261123170000_add_profile_tags.sql', 'utf8');

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

    const species = [
      'Domestic Dog (Canis lupus familiaris)',
      'Golden Retriever (Canis familiaris)',
      'DOMESTIC CAT (Felis catus)',
      'Dog, Cat, Dog',
      'Prairie dog',
      'Catfish',
      null,
      'Rabbit',
      ' ',
    ];
    for (let n = 1; n <= species.length; n++) {
      await db.query('insert into public.reports values ($1, $2, $3, $4)',
        [id(n), owner, 'approved', species[n - 1]]);
    }
    for (const [n, account, status, animal] of [
      [10, other, 'approved', 'Dog'],
      [11, owner, 'pending', 'Dog'],
      [12, owner, 'declined', 'Cat'],
      [13, owner, 'changes_requested', 'Dog'],
    ]) {
      await db.query('insert into public.reports values ($1, $2, $3, $4)',
        [id(n), account, status, animal]);
    }
    async function analysis(n, report, status, date, guesses) {
      await db.query('insert into public.ai_analyses values ($1,$2,$3,$4,$5)',
        [id(n), id(report), status, JSON.stringify(guesses), date]);
    }
    await analysis(20, 7, 'completed', '2026-11-20', [
      { common_name: 'Bird' },
    ]);
    await analysis(21, 7, 'completed', '2026-11-21', [
      { common_name: 'Cat', scientific_name: 'Felis catus' },
      { common_name: 'Dog', scientific_name: 'Canis familiaris' },
    ]);
    await analysis(22, 8, 'completed', '2026-11-21', [
      { common_name: 'Dog' },
    ]);
    await analysis(23, 9, 'completed', '2026-11-20', [
      { common_name: 'Dog', scientific_name: 'Canis familiaris' },
    ]);
    await analysis(24, 9, 'failed', '2026-11-21', [
      { common_name: 'Cat' },
    ]);

    await db.exec('set role anon');
    await assert.rejects(db.query('select * from public.my_profile_tag_activity()'), /permission denied/);
    await db.exec(`reset role; set role authenticated;
      set request.jwt.claim.sub = '${owner}'`);
    const own = (await db.query('select * from public.my_profile_tag_activity()')).rows;
    assert.deepEqual(own, [{ approved_reports: 9, dog_reports: 4, cat_reports: 3 }]);
    assert.deepEqual(Object.keys(own[0]).sort(), ['approved_reports', 'cat_reports', 'dog_reports']);
    assert.equal((await db.query('select * from public.reports where user_id = $1', [other])).rows.length, 0);

    for (const tag of ['dog_lover', 'cat_lover', 'spotter', null]) {
      const saved = await db.query('update public.profiles set profile_tag = $1 where id = $2 returning profile_tag',
        [tag, owner]);
      assert.deepEqual(saved.rows, [{ profile_tag: tag }]);
    }
    await assert.rejects(
      db.query('update public.profiles set profile_tag = $1 where id = $2', ['admin', owner]),
      /profiles_profile_tag_check/);
    const notMine = await db.query('update public.profiles set profile_tag = $1 where id = $2 returning id',
      ['dog_lover', other]);
    assert.equal(notMine.rows.length, 0);
    await db.exec("set test.suspended = 'true'");
    assert.equal((await db.query('update public.profiles set profile_tag = $1 where id = $2 returning id',
      ['dog_lover', owner])).rows.length, 0);
    await db.exec("set test.suspended = 'false'");

    await db.exec(`set request.jwt.claim.sub = '${other}'`);
    assert.deepEqual((await db.query('select * from public.my_profile_tag_activity()')).rows,
      [{ approved_reports: 1, dog_reports: 1, cat_reports: 0 }]);
    await db.exec("set request.jwt.claim.sub = ''");
    assert.deepEqual((await db.query('select * from public.my_profile_tag_activity()')).rows,
      [{ approved_reports: 0, dog_reports: 0, cat_reports: 0 }]);
    console.log('Profile tag SQL: idempotence, species counts, account isolation and RLS checks passed.');
  } finally {
    await db.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
