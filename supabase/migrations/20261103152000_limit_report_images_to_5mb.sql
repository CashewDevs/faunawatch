-- Enforce the mobile post-photo limit in private Supabase Storage as well.
-- This limits future uploads; existing objects and access policies are unchanged.
update storage.buckets
set file_size_limit = 5242880
where id = 'report-images';
