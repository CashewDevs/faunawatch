// Local-only PostgreSQL integration test; never connects to hosted Supabase.
// npm install --prefix .dart_tool/public-profile-sql --no-save --no-package-lock --ignore-scripts @electric-sql/pglite
// node test/features/public_profile/public_gallery_security_test.cjs [pglite-module-path]
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { PGlite } = require(path.resolve(process.argv[2] ||
  '.dart_tool/public-profile-sql/node_modules/@electric-sql/pglite'));
const db = new PGlite();
const viewer = '00000000-0000-4000-8000-000000000001';
const author = '00000000-0000-4000-8000-000000000002';
const other = '00000000-0000-4000-8000-000000000003';
const reportId = (i) => `10000000-0000-4000-8000-${String(i).padStart(12, '0')}`;
const migration = fs.readFileSync(
  'supabase/migrations/20261121233000_create_public_profile_gallery.sql', 'utf8');

(async () => {
  try {
    await db.exec(`
      create role anon; create role authenticated;
      create schema auth;
      create function auth.uid() returns uuid language sql stable as
        $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
      grant usage on schema public, auth to anon, authenticated;
      create type public.report_category as enum
        ('animal_in_need', 'possible_invasive_species', 'potentially_dangerous_animal', 'other_wildlife_incident');
      create type public.severity_level as enum ('low', 'medium', 'high');
      create table public.profiles (
        id uuid primary key, username text, full_name text, display_name text, avatar_path text
      );
      create table public.reports (
        id uuid primary key, user_id uuid references public.profiles,
        category public.report_category, description text, user_species text,
        place_name text, status text, created_at timestamptz,
        latitude double precision, longitude double precision, user_notes text
      );
      create table public.report_reviews (
        id uuid primary key, report_id uuid, decision text, decided_at timestamptz
      );
      create table public.report_images (
        id uuid primary key, report_id uuid, storage_path text, created_at timestamptz
      );
      create table public.ai_analyses (
        id uuid primary key, report_id uuid, status text,
        severity public.severity_level, possible_species jsonb, possible_invasive boolean,
        created_at timestamptz
      );
      create table public.report_comments (id uuid primary key, report_id uuid);
      create function public.is_report_approved(p_id uuid) returns boolean
        language sql stable security definer set search_path = '' as
        $$ select exists(select 1 from public.reports where id = p_id and status = 'approved') $$;
      create function public.is_suspended(uuid) returns boolean language sql as $$ select false $$;
      create function public.is_comment_visible(uuid) returns boolean language sql as $$ select true $$;
      create function public.report_id_from_image_path(p_path text) returns uuid language sql as
        $$ select split_part(p_path, '/', 1)::uuid $$;
      alter table public.reports enable row level security;
      grant select on public.reports to authenticated;
      create policy owner_reports on public.reports for select to authenticated
        using (user_id = auth.uid());
      insert into public.profiles(id, username, avatar_path) values
        ('${viewer}', 'Viewer', null), ('${author}', 'Forest Ranger', 'preset:panda'),
        ('${other}', 'Other author', null);
    `);
    // Use the real feed projection, rather than mocking its return fields.
    await db.exec(fs.readFileSync('supabase/migrations/20261112100000_create_community_feed.sql', 'utf8'));
    await db.exec(migration);
    await db.exec(migration); // Re-running the supplied script is safe.

    for (let i = 1; i <= 6; i++) {
      const status = i === 4 ? 'pending' : i === 5 ? 'declined' : i === 6 ? 'changes_requested' : 'approved';
      const category = i === 2 ? 'possible_invasive_species' : 'animal_in_need';
      await db.query(`insert into public.reports
        (id, user_id, category, description, user_species, place_name, status, created_at, latitude, longitude, user_notes)
        values ($1, $2, $3, 'Public description', 'Eagle', 'Cebu', $4, $5, 10.123456, 123.123456, 'Private note')`,
        [reportId(i), author, category, status, i === 1 ? '2026-11-18T00:00:00Z' : '2026-11-19T00:00:00Z']);
    }
    // A busy global feed must not fill or truncate the selected author's page.
    for (let i = 10; i < 70; i++) {
      await db.query(`insert into public.reports
        (id, user_id, category, status, created_at)
        values ($1, $2, 'animal_in_need', 'approved', '2026-11-21T00:00:00Z')`, [reportId(i), other]);
    }
    await db.query(`insert into public.report_images values
      (gen_random_uuid(), $1, $2, now())`, [reportId(3), `${reportId(3)}/photo.webp`]);
    await db.query(`insert into public.report_likes(report_id, user_id) values ($1, $2)`, [reportId(3), viewer]);

    await db.exec(`set role anon;`);
    await assert.rejects(db.query(`select * from public.public_profile_gallery('${author}')`), /permission denied/);
    await db.exec(`reset role; set role authenticated; set request.jwt.claim.sub = '';`);
    assert.equal((await db.query(`select * from public.public_profile_gallery('${author}')`)).rows.length, 0);
    await db.exec(`set request.jwt.claim.sub = '${viewer}';`);
    assert.equal((await db.query(`select * from public.reports where user_id = '${author}'`)).rows.length, 0,
      'The new RPC does not broaden direct table access.');

    const first = (await db.query(`select * from public.public_profile_gallery($1, p_limit => 2)`, [author])).rows;
    assert.deepEqual(first.map((row) => row.id), [reportId(3), reportId(2)]);
    assert(first.every((row) => row.author_id === author));
    assert.equal(first[0].author_name, 'Forest Ranger');
    assert.equal(first[0].liked_by_me, true);
    assert.equal(first[0].like_count, 1);
    assert.deepEqual(first[0].photo_paths, [`${reportId(3)}/photo.webp`]);
    for (const field of ['latitude', 'longitude', 'user_notes', 'status', 'admin_id', 'email']) {
      assert(!Object.hasOwn(first[0], field), `${field} is private`);
    }
    const older = (await db.query(`select * from public.public_profile_gallery($1, $2, $3, 2)`,
      [author, first[1].created_at, first[1].id])).rows;
    assert.deepEqual(older.map((row) => row.id), [reportId(1)]);
    const filtered = (await db.query(`select * from public.public_profile_gallery($1,
      p_limit => 1, p_category => 'possible_invasive_species')`, [author])).rows;
    assert.deepEqual(filtered.map((row) => row.id), [reportId(2)], 'Category filtering happens before LIMIT.');
    assert.equal((await db.query(`select * from public.public_profile_gallery($1, p_limit => 0)`, [author])).rows.length, 1);
    assert.equal((await db.query(`select * from public.public_profile_gallery($1, p_limit => 999)`, [other])).rows.length, 50);
    assert.equal((await db.query(`select * from public.public_profile_gallery($1, p_before_id => $2)`,
      [author, reportId(2)])).rows.length, 0, 'An incomplete cursor does not restart the gallery.');
    assert.equal((await db.query(`select * from public.public_profile_gallery('${viewer}')`)).rows.length, 0);

    await db.exec(`reset role; update public.reports set status = 'declined' where id = '${reportId(3)}';
      set role authenticated;`);
    const afterReview = (await db.query(`select * from public.public_profile_gallery('${author}')`)).rows;
    assert.deepEqual(afterReview.map((row) => row.id), [reportId(2), reportId(1)], 'Revoked reports leave the public gallery.');
    console.log('Public gallery PostgreSQL checks passed: permissions, public fields, approved-only visibility, author/category filtering, cursors, limits, and reapplication.');
  } finally {
    await db.close();
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
