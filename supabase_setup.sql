-- ============================================================
-- LifeHasBeenDull — Supabase schema
-- Run this once in your Supabase project's SQL Editor
-- (Project → SQL Editor → New query → paste all of this → Run)
-- ============================================================

-- ------------------------------------------------------------
-- 1. TOPICS  (the six realms/categories — Career, Health, etc.)
-- ------------------------------------------------------------
create table if not exists topics (
  id               text primary key,
  icon             text not null,
  name_fellowship  text not null,
  name_glass       text not null,
  name_book        text not null,
  desc_fellowship  text not null,
  desc_glass       text not null,
  desc_book        text not null,
  sort_order       int not null default 0
);

-- ------------------------------------------------------------
-- 2. GOALS  ("Notepad #1" — approved, live goals shown to users)
-- ------------------------------------------------------------
create table if not exists goals (
  id          uuid primary key default gen_random_uuid(),
  topic_id    text not null references topics(id) on delete cascade,
  difficulty  text not null check (difficulty in ('easy','medium','hard')),
  text        text not null,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. SUGGESTIONS  ("Notepad #2" — pending user submissions)
-- ------------------------------------------------------------
create table if not exists suggestions (
  id              uuid primary key default gen_random_uuid(),
  submitted_at    timestamptz not null default now(),
  theme           text not null,
  topic_id        text not null references topics(id) on delete cascade,
  difficulty      text not null check (difficulty in ('easy','medium','hard')),
  text            text not null,
  status          text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewer_notes  text default ''
);

-- ------------------------------------------------------------
-- 4. ROW LEVEL SECURITY
--    Public (anon key, used by index.html) can:
--      - read topics and goals
--      - insert suggestions
--    It can NOT read, edit, or delete suggestions, and can NOT
--    write to topics/goals — only a signed-in admin (admin.html) can.
-- ------------------------------------------------------------
alter table topics      enable row level security;
alter table goals       enable row level security;
alter table suggestions enable row level security;

-- Public read access
create policy "public read topics" on topics
  for select using (true);

create policy "public read goals" on goals
  for select using (true);

-- Public can submit suggestions, but never read/update/delete them
create policy "public insert suggestions" on suggestions
  for insert with check (true);

-- Admin (any authenticated user — see SETUP.md to create the one admin login)
create policy "admin read suggestions" on suggestions
  for select using (auth.role() = 'authenticated');

create policy "admin update suggestions" on suggestions
  for update using (auth.role() = 'authenticated');

create policy "admin write goals" on goals
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

create policy "admin write topics" on topics
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ------------------------------------------------------------
-- 5. SEED DATA — carries over everything that used to be
--    hardcoded in the HTML/JS file
-- ------------------------------------------------------------
insert into topics (id, icon, name_fellowship, name_glass, name_book, desc_fellowship, desc_glass, desc_book, sort_order) values
('career',        '◈', 'The Forge',        'Career & Productivity', 'Work & Purpose',  'Work, focus, craft',   'Focus, growth, craft',  'Vocation, calling',    1),
('health',        '◎', 'The Body''s Path', 'Health & Fitness',      'Body & Vitality',  'Strength, vitality',   'Body, energy, habits',  'Strength, rest, care', 2),
('relationships',  '◉', 'Fellowship',       'Relationships',         'People & Love',    'Bonds, kinship, love', 'Connection, kindness',  'Bonds, presence',      3),
('creativity',     '◇', 'The Artisan',      'Creativity',            'Making & Art',     'Making, imagining',    'Art, play, expression', 'Creation, expression', 4),
('mindfulness',    '○', 'The Still Wood',   'Mindfulness',           'Inner Life',       'Peace, presence',      'Calm, clarity',         'Stillness, reflection',5),
('finance',        '◆', 'The Treasury',     'Finance & Money',       'Resources',        'Wealth, stewardship',  'Wealth, security',      'Stewardship, sufficiency', 6)
on conflict (id) do nothing;

insert into goals (topic_id, difficulty, text) values
('career','easy','Write down every task weighing on your mind and pick just one to finish today.'),
('career','easy','Spend 30 minutes clearing your inbox down to only what needs a reply.'),
('career','easy','Block one hour this week with no meetings and use it only for deep work.'),
('career','medium','Draft the proposal or document you have been postponing for more than a week.'),
('career','medium','Have the direct conversation with a colleague you have been avoiding.'),
('career','medium','Map out your next 30 days and identify where your time is being lost.'),
('career','hard','Dedicate five focused hours this week to the single project that matters most to your long-term path.'),
('career','hard','Reach out to three people in your field you admire and start a real conversation.'),
('career','hard','Audit every recurring commitment you have and eliminate at least one that no longer serves you.'),

('health','easy','Drink eight glasses of water today without exception.'),
('health','easy','Take a 20-minute walk outside before the day ends.'),
('health','easy','Sleep before midnight tonight and rise without hitting snooze.'),
('health','medium','Complete four workouts this week, each at least 30 minutes long.'),
('health','medium','Cook every meal you eat for the next five days from whole ingredients.'),
('health','medium','Cut out one food or drink that you know is harming you, for the entire week.'),
('health','hard','Train every morning this week before 7 AM, without negotiation.'),
('health','hard','Run or walk a total of 30 kilometres across this week.'),
('health','hard','Go one full week without alcohol, refined sugar, and processed food simultaneously.'),

('relationships','easy','Send a message to someone you have not spoken to in over a month.'),
('relationships','easy','Call a family member you love and simply listen to them for 20 minutes.'),
('relationships','easy','Write a note of genuine appreciation to someone who has helped you recently.'),
('relationships','medium','Plan and follow through on a meaningful evening with someone important to you.'),
('relationships','medium','Have an honest conversation about something you have been keeping to yourself.'),
('relationships','medium','Apologise sincerely to someone you have wronged, without justification.'),
('relationships','hard','Initiate the difficult conversation in a relationship that has been quietly suffering.'),
('relationships','hard','Spend an entire day fully present with the people you love — no phone, no distraction.'),
('relationships','hard','Commit to one act of service for someone who cannot repay you, this week.'),

('creativity','easy','Spend 30 minutes making something with no purpose other than the joy of making.'),
('creativity','easy','Write three pages in longhand about anything at all, without editing.'),
('creativity','easy','Sketch or doodle for 20 minutes before you open any screen today.'),
('creativity','medium','Complete one creative piece — a chapter, a painting, a song — start to finish this week.'),
('creativity','medium','Set aside two hours each day for creative work and protect them like appointments.'),
('creativity','medium','Share something you have made with at least one other person, however unfinished it feels.'),
('creativity','hard','Commit to one hour of creative practice every single morning this week before anything else.'),
('creativity','hard','Finish and publish or share a complete creative work by the end of this week.'),
('creativity','hard','Start the project you have been imagining for months and produce something tangible by Sunday.'),

('mindfulness','easy','Sit in silence for ten minutes today with no phone, no music, no input.'),
('mindfulness','easy','Before bed, write three things that were genuinely good about today.'),
('mindfulness','easy','Eat one meal today slowly, without a screen, noticing every bite.'),
('mindfulness','medium','Meditate for 20 minutes each morning this week, before looking at your phone.'),
('mindfulness','medium','Keep a journal entry every night this week reflecting on what you felt, not just what you did.'),
('mindfulness','medium','Spend one full afternoon this week in nature with no agenda and no device.'),
('mindfulness','hard','Begin each day this week in silence for 30 minutes before speaking to anyone.'),
('mindfulness','hard','Observe a full digital sabbath — one day this week with no screens at all.'),
('mindfulness','hard','Write down every anxious thought the moment it arises each day this week, then consciously let it go.'),

('finance','easy','Write down every purchase you made in the last seven days and total them honestly.'),
('finance','easy','Cancel one subscription you have not used in the last month.'),
('finance','easy','Transfer a small amount — even symbolic — into your savings account today.'),
('finance','medium','Build a complete budget for next month and identify where you will cut 10% of spending.'),
('finance','medium','Research and open a savings or investment account you have been putting off.'),
('finance','medium','Negotiate one bill, subscription, or rate that you have been paying without questioning.'),
('finance','hard','Track every single penny you spend this week and sit with what it reveals about your values.'),
('finance','hard','Set a concrete financial goal with a deadline and build a week-by-week plan to reach it.'),
('finance','hard','Have the honest money conversation with your partner, family, or yourself that you have been avoiding.');
