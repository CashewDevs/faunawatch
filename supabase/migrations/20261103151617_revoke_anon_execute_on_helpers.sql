-- =============================================================================
-- Migration: revoke_anon_execute_on_helpers
-- Why: Postgres grants EXECUTE on new functions to PUBLIC by default.
--      is_suspended() and is_comment_visible() never revoked it, so
--      signed-out (anon) callers could use them through the API, e.g. to
--      probe whether a user is suspended. Both are only needed by RLS
--      policies that run for signed-in users, so execute is limited to
--      authenticated, matching is_admin() and the admin RPCs.
-- =============================================================================

revoke execute on function public.is_suspended(uuid) from public, anon;
grant  execute on function public.is_suspended(uuid) to authenticated;

revoke execute on function public.is_comment_visible(uuid) from public, anon;
grant  execute on function public.is_comment_visible(uuid) to authenticated;
