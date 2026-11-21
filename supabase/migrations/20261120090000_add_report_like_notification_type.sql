-- =============================================================================
-- Migration: add_report_like_notification_type
-- Why: Like notifications need a new notification_type value, 'report_like'.
--      Postgres does not allow a newly added enum value to be used in the
--      transaction that added it, and the Supabase SQL editor runs a file as
--      one transaction. So the value is added here, ALONE, and everything that
--      uses it lives in the next migration.
--
-- New: notification_type value 'report_like'.
-- Changed: nothing existing. Safe to run again (if not exists).
-- Apply after 20261114041037_derive_report_ai_status.sql, and run it (and let
-- it finish) BEFORE 20261120090100_add_like_and_pending_notifications.sql.
-- =============================================================================

alter type public.notification_type add value if not exists 'report_like';
