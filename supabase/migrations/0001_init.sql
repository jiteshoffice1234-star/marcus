-- ============================================================================
-- Accounting Academy — Initial schema (migration 0001)
-- PostgreSQL / Supabase
--
-- Design notes:
--  * All PKs are UUIDs generated with gen_random_uuid() (pgcrypto).
--  * Amounts are NUMERIC (exact decimal arithmetic — never FLOAT for money).
--  * Content tables (levels/subjects/chapters/topics/lessons/questions/...)
--    carry deleted_at for soft deletion so historical attempts keep resolving.
--  * RLS is enabled on every table. Content is read by authenticated users;
--    learner-owned rows are visible only to their owner; admins (role in
--    profiles) may manage content.
--  * audit_logs is append-only via RLS (INSERT only, no UPDATE/DELETE).
--  * An auth trigger auto-creates a profile row on signup.
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.difficulty as enum ('beginner', 'easy', 'intermediate', 'advanced', 'ca_final');
create type public.question_type as enum (
  'mcq',
  'numerical',
  'journal_entry',
  'fill_blank',
  'true_false',
  'error_correction',
  'match_items',
  'financial_statement',
  'case_study',
  'multi_step'
);
create type public.answer_status as enum ('correct', 'incorrect', 'partial', 'skipped');
create type public.test_type as enum ('topic', 'chapter', 'level', 'mixed', 'professional', 'ca_final_mock');
create type public.revision_state as enum ('new', 'learning', 'reviewing', 'mastered');
create type public.role as enum ('learner', 'admin');
create type public.source as enum ('assessment', 'practice', 'test', 'simulator', 'manual');

-- ---------------------------------------------------------------------------
-- Users / profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  full_name       text,
  email           citext unique,
  role            public.role not null default 'learner',
  avatar_url      text,
  daily_goal_questions int not null default 10,
  starting_level_id uuid, -- set after the initial assessment
  onboarded       boolean not null default false,
  assessment_taken boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Curriculum (content — soft deletable)
-- ---------------------------------------------------------------------------
create table public.courses (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  title       text not null,
  description text,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.levels (
  id          uuid primary key default gen_random_uuid(),
  course_id   uuid not null references public.courses (id) on delete cascade,
  slug        text not null,
  title       text not null,          -- e.g. "Accounting Foundation"
  subtitle    text,
  description text,
  level_index int not null default 0, -- 1..4 (Foundation → CA Final)
  icon        text,
  accent_color text,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (course_id, slug)
);

create table public.subjects (
  id          uuid primary key default gen_random_uuid(),
  level_id    uuid not null references public.levels (id) on delete cascade,
  slug        text not null,
  title       text not null,
  description text,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (level_id, slug)
);

create table public.chapters (
  id          uuid primary key default gen_random_uuid(),
  subject_id  uuid not null references public.subjects (id) on delete cascade,
  slug        text not null,
  title       text not null,
  description text,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (subject_id, slug)
);

create table public.topics (
  id          uuid primary key default gen_random_uuid(),
  chapter_id  uuid not null references public.chapters (id) on delete cascade,
  slug        text not null,
  title       text not null,
  description text,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (chapter_id, slug)
);

create table public.lessons (
  id          uuid primary key default gen_random_uuid(),
  topic_id    uuid not null references public.topics (id) on delete cascade,
  slug        text not null,
  title       text not null,
  summary     text,
  -- Structured lesson body stored as JSON: sections [{type, heading, body, table?, formula?}]
  content     jsonb not null default '[]'::jsonb,
  difficulty  public.difficulty not null default 'beginner',
  estimated_minutes int not null default 5,
  is_published boolean not null default true,
  sort_order  int not null default 0,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (topic_id, slug)
);

-- ---------------------------------------------------------------------------
-- Questions
-- ---------------------------------------------------------------------------
create table public.questions (
  id             uuid primary key default gen_random_uuid(),
  topic_id       uuid references public.topics (id) on delete cascade,
  chapter_id     uuid references public.chapters (id) on delete cascade,
  level_id       uuid references public.levels (id) on delete cascade,
  question_type  public.question_type not null,
  difficulty     public.difficulty not null default 'easy',
  stem           text not null,                       -- the question text
  -- Machine-readable answer. For mcq/true_false: option key(s).
  -- For numerical: exact value. For journal_entry: JSON {debits:[{account,amount}], credits:[...]}.
  -- For fill_blank: list of accepted answers.
  answer         jsonb not null,
  explanation    text,                                -- why the answer is right
  why_others_wrong jsonb not null default '[]'::jsonb, -- [{option, why}] for MCQ
  common_mistake text,
  hint           text,
  tags           text[] not null default '{}',
  skills         text[] not null default '{}',        -- e.g. {debit_credit, journal}
  marks          numeric(6,2) not null default 1,
  negative_marks numeric(6,2) not null default 0,
  estimated_seconds int not null default 60,
  is_published   boolean not null default true,
  deleted_at     timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index idx_questions_topic on public.questions (topic_id) where deleted_at is null;
create index idx_questions_chapter on public.questions (chapter_id) where deleted_at is null;
create index idx_questions_level on public.questions (level_id) where deleted_at is null;
create index idx_questions_difficulty on public.questions (difficulty);
create index idx_questions_skills on public.questions using gin (skills);

create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete cascade,
  option_key  text not null,           -- 'A','B','C','D' (or match-pair keys)
  text        text not null,
  is_correct  boolean not null default false,
  sort_order  int not null default 0,
  unique (question_id, option_key)
);

-- ---------------------------------------------------------------------------
-- Attempts (every answer, right or wrong — feeds the mistake engine)
-- ---------------------------------------------------------------------------
create table public.attempts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  source      public.source not null default 'practice',
  source_ref  uuid,                   -- test_attempt id / simulation id when relevant
  user_answer jsonb not null,         -- raw answer as submitted
  status      public.answer_status not null,
  marks_earned numeric(6,2) not null default 0,
  time_taken_seconds int,
  created_at  timestamptz not null default now()
);

create index idx_attempts_user on public.attempts (user_id, created_at desc);
create index idx_attempts_question on public.attempts (question_id);
create index idx_attempts_status on public.attempts (user_id, status) where status = 'incorrect';

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------
create table public.tests (
  id              uuid primary key default gen_random_uuid(),
  slug            text unique not null,
  title           text not null,
  description     text,
  test_type       public.test_type not null,
  level_id        uuid references public.levels (id),
  chapter_id      uuid references public.chapters (id),
  topic_id        uuid references public.topics (id),
  duration_minutes int not null default 10,
  negative_marking numeric(6,2) not null default 0,
  pass_percentage numeric(5,2) not null default 40,
  is_published    boolean not null default true,
  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.test_questions (
  test_id     uuid not null references public.tests (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  sort_order  int not null default 0,
  primary key (test_id, question_id)
);

create table public.test_attempts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  test_id     uuid not null references public.tests (id) on delete cascade,
  started_at  timestamptz not null default now(),
  submitted_at timestamptz,
  answers     jsonb not null default '{}'::jsonb, -- question_id -> user answer
  marked_for_review text[] not null default '{}',
  score       numeric(8,2),
  max_score   numeric(8,2),
  correct_count int,
  incorrect_count int,
  skipped_count int,
  accuracy    numeric(5,2),
  status      text not null default 'in_progress'  -- in_progress | submitted
);

create index idx_test_attempts_user on public.test_attempts (user_id, started_at desc);

-- ---------------------------------------------------------------------------
-- Progress / skills / mistakes / revision
-- ---------------------------------------------------------------------------
create table public.user_progress (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  content_type text not null,          -- lesson | topic | chapter | level | question
  content_id  uuid not null,
  status      text not null default 'in_progress', -- in_progress | completed
  progress    numeric(5,2) not null default 0,     -- 0..100
  xp_earned   int not null default 0,
  completed_at timestamptz,
  updated_at  timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create index idx_user_progress_user on public.user_progress (user_id);

create table public.user_skills (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  skill_key   text not null,           -- e.g. 'debit_credit', 'consolidation'
  level       numeric(5,2) not null default 0,  -- 0..100 mastery estimate
  attempts    int not null default 0,
  correct     int not null default 0,
  accuracy    numeric(5,2) not null default 0,
  updated_at  timestamptz not null default now(),
  unique (user_id, skill_key)
);

create table public.mistakes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  topic_id    uuid references public.topics (id),
  skill_key   text,
  wrong_answer jsonb,
  count       int not null default 1,
  last_missed_at timestamptz not null default now(),
  resolved    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (user_id, question_id)
);

create index idx_mistakes_user on public.mistakes (user_id, resolved);

create table public.revision_queue (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  content_type  text not null,          -- question | lesson | topic
  content_id    uuid not null,
  skill_key     text,
  state         public.revision_state not null default 'new',
  interval_days int not null default 1,
  due_at        timestamptz not null default now(),
  repetitions   int not null default 0,
  ease          numeric(5,2) not null default 2.5,  -- SuperMemo/Anki-style ease
  last_reviewed_at timestamptz,
  created_at    timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create index idx_revision_due on public.revision_queue (user_id, due_at);

-- ---------------------------------------------------------------------------
-- Bookmarks / notes
-- ---------------------------------------------------------------------------
create table public.bookmarks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  content_type text not null,          -- lesson | question | reference | case_study
  content_id   uuid not null,
  created_at   timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

create table public.notes (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  title       text not null,
  body        text not null,
  content_type text,                    -- lesson | question | concept
  content_id  uuid,
  is_mistake_note boolean not null default false,
  search_text text generated always as (lower(title || ' ' || body)) stored,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_notes_user on public.notes (user_id);
create index idx_notes_search on public.notes using gin (to_tsvector('english', title || ' ' || body));

-- ---------------------------------------------------------------------------
-- Gamification
-- ---------------------------------------------------------------------------
create table public.achievements (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  title       text not null,
  description text,
  icon        text,
  xp_reward   int not null default 0
);

create table public.user_achievements (
  user_id       uuid not null references auth.users (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id) on delete cascade,
  unlocked_at   timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create table public.streaks (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  current      int not null default 0,
  longest      int not null default 0,
  last_active_date date,
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Simulator
-- ---------------------------------------------------------------------------
create table public.simulations (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  title       text not null,
  description text,
  company_name text not null,
  industry    text,
  level_id    uuid references public.levels (id),
  starting_balances jsonb not null default '{}'::jsonb, -- account -> amount (opening TB)
  difficulty  public.difficulty not null default 'intermediate',
  expected_statements jsonb not null default '{}'::jsonb, -- engine-checked reference
  is_published boolean not null default true,
  deleted_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.simulation_transactions (
  id              uuid primary key default gen_random_uuid(),
  simulation_id   uuid not null references public.simulations (id) on delete cascade,
  seq             int not null,
  narration       text not null,       -- "Purchased inventory on credit from X"
  transaction_type text not null,
  amount          numeric(19,2) not null,
  expected_journal jsonb not null,     -- [{debit:{account,amount}}, ...]
  hints           text[] not null default '{}',
  sort_order      int not null default 0,
  unique (simulation_id, seq)
);

create table public.user_simulations (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  simulation_id uuid not null references public.simulations (id) on delete cascade,
  state         jsonb not null default '{}'::jsonb, -- journal entries accepted so far
  current_step  int not null default 1,
  status        text not null default 'in_progress',
  started_at    timestamptz not null default now(),
  completed_at  timestamptz,
  accuracy      numeric(5,2)
);

-- ---------------------------------------------------------------------------
-- Subscriptions / billing (kept minimal; revenue is a later phase)
-- ---------------------------------------------------------------------------
create table public.subscriptions (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  plan           text not null default 'free',
  status         text not null default 'active',  -- active | past_due | canceled
  provider       text,                            -- stripe | revenuecat | ...
  provider_ref   text,
  current_period_end timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Audit log (append-only)
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users (id) on delete set null,
  action     text not null,
  entity     text,
  entity_id  uuid,
  metadata   jsonb,
  ip         inet,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_user on public.audit_logs (user_id, created_at desc);
create index idx_audit_logs_entity on public.audit_logs (entity, entity_id);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','courses','levels','subjects','chapters','topics','lessons',
    'questions','tests','user_progress','user_skills','mistakes','notes',
    'revision_queue','simulations','simulation_transactions','subscriptions'
  ] loop
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Auto-create profile on signup
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.email)
  on conflict (id) do nothing;
  insert into public.streaks (user_id) values (new.id) on conflict do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Helpers + RLS
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  );
$$;

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.levels enable row level security;
alter table public.subjects enable row level security;
alter table public.chapters enable row level security;
alter table public.topics enable row level security;
alter table public.lessons enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.attempts enable row level security;
alter table public.tests enable row level security;
alter table public.test_questions enable row level security;
alter table public.test_attempts enable row level security;
alter table public.user_progress enable row level security;
alter table public.user_skills enable row level security;
alter table public.mistakes enable row level security;
alter table public.revision_queue enable row level security;
alter table public.bookmarks enable row level security;
alter table public.notes enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.streaks enable row level security;
alter table public.simulations enable row level security;
alter table public.simulation_transactions enable row level security;
alter table public.user_simulations enable row level security;
alter table public.subscriptions enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: owner manages own; admins read all
create policy "profiles_owner_select" on public.profiles for select using (auth.uid() = id or public.is_admin());
create policy "profiles_owner_update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id and role = 'learner');
create policy "profiles_admin_insert" on public.profiles for insert with check (auth.uid() = id or public.is_admin());
-- (trigger creates profiles; admin inserts allowed via the check above)

-- Content: readable by any authenticated user; only admins write
create policy "content_read" on public.courses for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.levels for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.subjects for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.chapters for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.topics for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.lessons for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.questions for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "content_read" on public.question_options for select using (auth.role() = 'authenticated');
create policy "content_write" on public.courses for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.levels for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.subjects for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.chapters for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.topics for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.lessons for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.questions for all using (public.is_admin()) with check (public.is_admin());
create policy "content_write" on public.question_options for all using (public.is_admin()) with check (public.is_admin());

-- Learner-owned rows
create policy "attempts_owner" on public.attempts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "test_attempts_owner" on public.test_attempts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_progress_owner" on public.user_progress for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_skills_owner" on public.user_skills for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "mistakes_owner" on public.mistakes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "revision_owner" on public.revision_queue for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bookmarks_owner" on public.bookmarks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notes_owner" on public.notes for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_achievements_owner" on public.user_achievements for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "streaks_owner" on public.streaks for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_simulations_owner" on public.user_simulations for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "subscriptions_owner" on public.subscriptions for select using (auth.uid() = user_id);

-- Tests readable by authenticated users
create policy "tests_read" on public.tests for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "tests_read" on public.test_questions for select using (auth.role() = 'authenticated');
create policy "tests_write" on public.tests for all using (public.is_admin()) with check (public.is_admin());
create policy "tests_write" on public.test_questions for all using (public.is_admin()) with check (public.is_admin());

-- Simulations: content readable, user rows owner-only
create policy "simulations_read" on public.simulations for select using (auth.role() = 'authenticated' and deleted_at is null);
create policy "simulations_read" on public.simulation_transactions for select using (auth.role() = 'authenticated');
create policy "simulations_write" on public.simulations for all using (public.is_admin()) with check (public.is_admin());
create policy "simulations_write" on public.simulation_transactions for all using (public.is_admin()) with check (public.is_admin());

-- Achievements: content public to authenticated, unlocks owner-only
create policy "achievements_read" on public.achievements for select using (auth.role() = 'authenticated');
create policy "achievements_write" on public.achievements for all using (public.is_admin()) with check (public.is_admin());

-- Audit log: append-only
create policy "audit_insert" on public.audit_logs for insert with check (true);
create policy "audit_no_update" on public.audit_logs for update using (false);
create policy "audit_no_delete" on public.audit_logs for delete using (false);
create policy "audit_read_admin" on public.audit_logs for select using (public.is_admin());
