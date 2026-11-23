-- =============================================================================
-- Migration: drop_old_admin_suspend_user
-- Why: 20261123120100_add_suspension_levels.sql added
--      admin_suspend_user(user_id, category, level, reason, days) and kept the
--      older admin_suspend_user(user_id, reason, days) only so the live admin
--      site kept working until it was updated. The admin site now calls the
--      new version (faunawatch-admin PR #37), so the old one is removed. It
--      saved suspensions with no category and the 'restricted' level, which
--      can no longer be created.
--
-- Changed: drops admin_suspend_user(uuid, text, integer). The new version,
--   admin_reactivate_user(), user_sanctions and existing suspensions are
--   untouched. A browser tab still showing the old admin site gets "Couldn't
--   save the change" when suspending; reloading the page fixes it.
-- Apply after 20261123120100_add_suspension_levels.sql, once the updated
-- admin site is live. Safe to run again (if exists).
-- =============================================================================

drop function if exists public.admin_suspend_user(uuid, text, integer);
