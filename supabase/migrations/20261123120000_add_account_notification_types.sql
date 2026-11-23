-- =============================================================================
-- Migration: add_account_notification_types
-- Why: Suspending and reactivating a user will now tell them through an
--      in-app notification (which the app also receives live). That needs
--      two new notification_type values. Postgres does not allow a newly
--      added enum value to be used in the transaction that added it, and the
--      Supabase SQL editor runs a file as one transaction. So the values are
--      added here, ALONE, and everything that uses them lives in the next
--      migration.
--
-- New: notification_type values 'account_suspended' and 'account_reactivated'.
-- Changed: nothing existing. Safe to run again (if not exists). Older app
--   versions show unknown types as plain notifications.
-- Apply after 20261123083000_add_profile_bio.sql, and run it (and let it
-- finish) BEFORE 20261123120100_add_suspension_levels.sql.
-- =============================================================================

alter type public.notification_type add value if not exists 'account_suspended';
alter type public.notification_type add value if not exists 'account_reactivated';
