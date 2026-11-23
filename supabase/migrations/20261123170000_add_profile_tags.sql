-- Optional, owner-confirmed profile tags and an owner-only activity summary.
-- Apply manually after the existing profiles/reports/ai_analyses migrations.
-- No hosted changes are applied by the app. Existing RLS remains unchanged.

alter table public.profiles
  add column if not exists profile_tag text;

alter table public.profiles
  drop constraint if exists profiles_profile_tag_check;

alter table public.profiles
  add constraint profiles_profile_tag_check
  check (profile_tag in ('dog_lover', 'cat_lover', 'spotter'));

comment on column public.profiles.profile_tag is
  'Optional public interest tag explicitly confirmed by its owner.';

-- Counts only the caller's approved reports, once per report and animal type.
-- Explicit report species take precedence. With no entered species, only the
-- latest completed analysis's first guess is used, not its alternatives.
-- Comma-separated names cover the app's saved multi-animal species summaries.
create or replace function public.my_profile_tag_activity()
returns table (
  approved_reports bigint,
  dog_reports bigint,
  cat_reports bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  with approved_species as (
    select r.id as report_id,
      coalesce(
        nullif(pg_catalog.btrim(r.user_species), ''),
        pg_catalog.concat_ws(' ',
          nullif(pg_catalog.btrim(a.primary_species ->> 'common_name'), ''),
          case when nullif(pg_catalog.btrim(
            a.primary_species ->> 'scientific_name'), '') is not null
          then '(' || pg_catalog.btrim(
            a.primary_species ->> 'scientific_name') || ')'
          end
        )
      ) as species_names
    from public.reports r
    left join lateral (
      select analysis.possible_species -> 0 as primary_species
      from public.ai_analyses analysis
      where analysis.report_id = r.id and analysis.status = 'completed'
      order by analysis.created_at desc, analysis.id desc
      limit 1
    ) a on nullif(pg_catalog.btrim(r.user_species), '') is null
    where r.user_id = (select auth.uid()) and r.status = 'approved'
  ), normalized_names as (
    select r.report_id,
      pg_catalog.lower(pg_catalog.btrim(names.species_name)) as species_name
    from approved_species r
    cross join lateral pg_catalog.unnest(
      pg_catalog.string_to_array(r.species_names, ',')
    ) names(species_name)
  ), canonical_names as (
    select report_id,
      pg_catalog.btrim(pg_catalog.split_part(species_name, '(', 1)) as common_name,
      pg_catalog.btrim((pg_catalog.regexp_match(
        species_name, '\(([^()]*)\)'
      ))[1]) as scientific_name
    from normalized_names
  ), classified_reports as (
    select r.report_id,
      coalesce(pg_catalog.bool_or(
        n.common_name in ('dog', 'dogs', 'domestic dog', 'domestic dogs',
          'canis lupus familiaris', 'canis familiaris')
        or n.scientific_name in ('canis lupus familiaris', 'canis familiaris')
      ), false) as is_dog,
      coalesce(pg_catalog.bool_or(
        n.common_name in ('cat', 'cats', 'domestic cat', 'domestic cats',
          'felis catus', 'felis domesticus')
        or n.scientific_name in ('felis catus', 'felis domesticus')
      ), false) as is_cat
    from approved_species r
    left join canonical_names n on n.report_id = r.report_id
    group by r.report_id
  )
  select pg_catalog.count(*) as approved_reports,
    pg_catalog.count(*) filter (where is_dog) as dog_reports,
    pg_catalog.count(*) filter (where is_cat) as cat_reports
  from classified_reports;
$$;

revoke all on function public.my_profile_tag_activity() from public, anon;
grant execute on function public.my_profile_tag_activity() to authenticated;

comment on function public.my_profile_tag_activity() is
  'Owner-only approved-report counts for optional profile-tag suggestions. '
  'No unposted scans, photos, locations, notes or other accounts are returned.';

notify pgrst, 'reload schema';
