-- =============================================================================
-- Migration: add_changes_requested_status_and_change_enums
-- Why: Phase 5 "Request changes". Instead of approving or declining a pending
--      post, an admin can send it back to the reporter with a message and
--      ticks for what to fix. The reporter edits it and resubmits, and it
--      goes back to pending.
--
-- This migration only adds types. ALTER TYPE ... ADD VALUE can't be used in
-- the same transaction that uses the new value, so the table, policies and
-- functions that use them follow in add_report_change_requests (same
-- pattern as add_inappropriate_and_not_wildlife_decline_reasons).
--
--   report_status 'changes_requested': sent back, waiting for the reporter.
--   report_change_field: what the admin ticked as needing a fix
--     photos               the photo(s)
--     species_description  the species name and/or description and notes
--     location             the map location
--     category             the report category
--   change_request_resolution: how an open request was closed
--     resubmitted          the reporter sent the post back for review
--     withdrawn            an admin took the request back
--
-- Adds a value and two new types only; existing rows are unchanged.
-- =============================================================================


alter type public.report_status add value if not exists 'changes_requested';

create type public.report_change_field as enum (
  'photos',
  'species_description',
  'location',
  'category'
);

create type public.change_request_resolution as enum (
  'resubmitted',
  'withdrawn'
);
