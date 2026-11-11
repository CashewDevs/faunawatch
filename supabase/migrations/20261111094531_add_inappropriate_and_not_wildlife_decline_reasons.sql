-- =============================================================================
-- Migration: add_inappropriate_and_not_wildlife_decline_reasons
-- Why: The five agreed decline reasons all describe a wildlife report with a
--      problem (wrong species, poor photo, duplicate, ...). None fits a post
--      that is offensive, or that isn't about wildlife at all, so an admin
--      declining or taking down such a post had no honest reason to pick.
--
--   inappropriate_content: offensive, abusive or otherwise unsuitable content
--   not_wildlife:          unrelated to wildlife (selfies, pets' toys, spam)
--
-- Adds values only; existing rows and the five existing values are unchanged.
-- The admin site's decline reason list and analytics chart need the matching
-- keys (faunawatch-admin, src/features/analytics/models/analytics.ts).
-- =============================================================================


alter type public.decline_reason add value if not exists 'inappropriate_content';
alter type public.decline_reason add value if not exists 'not_wildlife';
