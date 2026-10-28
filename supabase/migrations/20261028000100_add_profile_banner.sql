-- Persist the existing preset-banner or solid-color profile choice.
-- Nullable columns preserve existing profiles; RLS remains unchanged.
alter table public.profiles
  add column banner_asset text,
  add column banner_color bigint,
  add constraint profiles_banner_color_range
    check (banner_color between 0 and 4294967295),
  add constraint profiles_banner_exclusive
    check (banner_asset is null or banner_color is null);

comment on column public.profiles.banner_asset is
  'Local preset banner asset identifier. Mutually exclusive with banner_color.';
comment on column public.profiles.banner_color is
  'Unsigned 32-bit ARGB solid banner color. Mutually exclusive with banner_asset.';
