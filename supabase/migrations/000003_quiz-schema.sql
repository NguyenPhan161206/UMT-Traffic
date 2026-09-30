-- 000003_quiz_schema.sql
-- Quiz questions and submissions for traffic safety contest

-- =====================================================
-- 1. SCHOOLS TABLE (Danh sách trường)
-- =====================================================
create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  city text,
  created_at timestamptz default now()
);

comment on table public.schools is 'List of participating high schools.';

-- =====================================================
-- 2. QUIZ_QUESTIONS TABLE
-- =====================================================
create table if not exists public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text not null,
  correct_answer text not null check (correct_answer in ('A', 'B', 'C', 'D')),
  explanation text, -- Explain why this is correct
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on table public.quiz_questions is 'Traffic safety quiz questions. Only admin can create/edit.';

-- =====================================================
-- 3. QUIZ_SUBMISSIONS TABLE (One submission per student)
-- =====================================================
create table if not exists public.quiz_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  answers jsonb not null, -- {"q1": "A", "q2": "B", ...}
  score integer, -- Calculated by RLS trigger
  submitted_at timestamptz default now(),
  unique(user_id) -- Only one submission per student
);

comment on table public.quiz_submissions is 'Student quiz submissions. One per student. Score auto-calculated.';

-- =====================================================
-- 4. UPDATED_AT TRIGGER
-- =====================================================
create trigger quiz_questions_set_updated_at
  before update on public.quiz_questions
  for each row
  execute function public.set_updated_at();

-- =====================================================
-- 5. RLS POLICIES
-- =====================================================

-- quiz_questions: Student can read, Admin can CRUD
alter table public.quiz_questions enable row level security;

drop policy if exists "quiz_questions_select_all" on public.quiz_questions;
drop policy if exists "quiz_questions_insert_admin" on public.quiz_questions;
drop policy if exists "quiz_questions_update_admin" on public.quiz_questions;
drop policy if exists "quiz_questions_delete_admin" on public.quiz_questions;

create policy "quiz_questions_select_all"
  on public.quiz_questions for select
  to authenticated
  using (true); -- All can view questions

create policy "quiz_questions_insert_admin"
  on public.quiz_questions for insert
  to authenticated
  with check (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

create policy "quiz_questions_update_admin"
  on public.quiz_questions for update
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

create policy "quiz_questions_delete_admin"
  on public.quiz_questions for delete
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

-- quiz_submissions: Student can create own, read own. Admin can read all and update scores.
alter table public.quiz_submissions enable row level security;

drop policy if exists "quiz_submissions_insert_own" on public.quiz_submissions;
drop policy if exists "quiz_submissions_select_own_or_admin" on public.quiz_submissions;
drop policy if exists "quiz_submissions_update_admin" on public.quiz_submissions;

create policy "quiz_submissions_insert_own"
  on public.quiz_submissions for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "quiz_submissions_select_own_or_admin"
  on public.quiz_submissions for select
  to authenticated
  using (
    user_id = auth.uid() OR
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

create policy "quiz_submissions_update_admin"
  on public.quiz_submissions for update
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

-- schools: Anyone can read
alter table public.schools enable row level security;

drop policy if exists "schools_select_all" on public.schools;
create policy "schools_select_all"
  on public.schools for select
  to authenticated
  using (true);

-- =====================================================
-- 6. FUNCTION: Calculate score
-- =====================================================
create or replace function public.calculate_quiz_score(
  p_answers jsonb,
  p_question_ids uuid[]
) returns integer as $$
declare
  v_score integer := 0;
  v_question record;
begin
  foreach v_question in array (
    select * from public.quiz_questions
    where id = any(p_question_ids)
    order by created_at
  )
  loop
    if p_answers->v_question.id::text = v_question.correct_answer::text then
      v_score := v_score + 1;
    end if;
  end loop;
  return v_score;
end;
$$ language plpgsql immutable security definer set search_path = '';

-- =====================================================
-- 7. GRANTS
-- =====================================================
revoke all on public.schools from anon, authenticated;
grant select on public.schools to authenticated;

revoke all on public.quiz_questions from anon, authenticated;
grant select, insert, update, delete on public.quiz_questions to authenticated;

revoke all on public.quiz_submissions from anon, authenticated;
grant select, insert, update on public.quiz_submissions to authenticated;

grant usage on schema public to authenticated;
grant execute on function public.calculate_quiz_score to authenticated;
