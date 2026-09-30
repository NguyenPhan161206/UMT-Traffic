-- 000004_profiles_update.sql
-- Add school and grade info to profiles table for contest registration

-- Add columns to profiles
alter table public.profiles
  add column if not exists school_id uuid references public.schools(id),
  add column if not exists grade text, -- "10", "11", "12"
  add column if not exists is_registered boolean default false;

-- Create index for filtering by school
create index idx_profiles_school_id on public.profiles(school_id);
create index idx_profiles_is_registered on public.profiles(is_registered);

comment on column public.profiles.school_id is 'Reference to schools table.';
comment on column public.profiles.grade is 'Student grade: 10, 11, or 12.';
comment on column public.profiles.is_registered is 'Has student completed registration for the contest.';

-- RLS: Students can only update their own profile during registration
alter table public.profiles force row level security;

-- Remove old policy if exists and add new one
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Admin can read all profiles
create policy "profiles_select_admin"
  on public.profiles for select
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );
