-- =============================================================================
-- Migration: create_community_responses
-- Why: Allows authenticated users to signal intent to assist with or provide
--      feedback on a report (SRS 3.1.4). Explicitly NOT a dispatch or
--      emergency commitment — the SRS states "I can assist / provide feedback".
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

create table if not exists public.community_responses (
  id              uuid primary key default gen_random_uuid(),

  report_id       uuid not null references public.reports   (id) on delete cascade,
  user_id         uuid not null references public.profiles  (id) on delete cascade,

  response_type   public.response_type   not null,
  status          public.response_status not null default 'active',
  -- TODO(open question): expand response_status enum once the full lifecycle
  --   is confirmed. See migration 1 comment.

  note            text,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.community_responses is
  'Community member responses to a report (can_assist / feedback). '
  'NOT a dispatch or emergency commitment (SRS 3.1.4). '
  'A user has at most one active response per report (enforced by unique constraint).';

create trigger community_responses_updated_at
  before update on public.community_responses
  for each row execute function public.set_updated_at();


-- ---------------------------------------------------------------------------
-- Constraints
-- ---------------------------------------------------------------------------

-- One active response per user per report. If a user withdraws and re-responds,
-- the existing row should be updated (or deleted + reinserted), not duplicated.
-- OPEN QUESTION: the SRS does not clarify whether a user can have multiple
-- historical responses. The unique constraint below enforces at-most-one;
-- if history is needed, drop this and add a partial unique on status='active'.
-- TODO(open question): is response history needed, or is one-per-user-per-report always correct?
alter table public.community_responses
  add constraint community_responses_one_per_user_per_report
  unique (user_id, report_id);


-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index if not exists community_responses_report_id_idx
  on public.community_responses (report_id);

create index if not exists community_responses_user_id_idx
  on public.community_responses (user_id);


-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.community_responses enable row level security;

-- Any authenticated user can view responses on any report
-- (Community map / report detail shows who has responded)
create policy "community_responses_select_authenticated"
  on public.community_responses
  for select
  to authenticated
  using (true);

-- Users can insert their own response
create policy "community_responses_insert_own"
  on public.community_responses
  for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Users can update their own response (e.g. change note, update status)
create policy "community_responses_update_own"
  on public.community_responses
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Users can delete (withdraw) their own response
create policy "community_responses_delete_own"
  on public.community_responses
  for delete
  to authenticated
  using (auth.uid() = user_id);
