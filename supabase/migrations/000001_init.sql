-- 000001_init.sql — infrastructure only.
--
-- SCOPE DELIBERATELY LIMITED. This file carries no business logic, because
-- rule 9 says scoring, duplicate-entry handling, deadlines, admin roles and
-- anti-cheat are undefined. There is no submissions table, no score column and
-- no scoring function here. Those need a decision from the client first:
--   - is the leaderboard readable by anon, or only by signed-in users?
--     This single answer changes the RLS shape of every results table.
-- Nothing below guesses it.
--
-- RLS enforcement was verified empirically against this local stack before this
-- file was written: a throwaway table with RLS enabled and zero policies
-- returned 0 rows to an authenticated caller, and adding
-- `using (auth.uid() = id)` made exactly the caller's own row visible while
-- hiding a row belonging to a different uuid. Anon saw 0 rows in both cases.

-- --- profiles ---------------------------------------------------------------
-- Identity data, one row per auth user. Deliberately carries no contest data,
-- so it stays valid regardless of how the business rules are decided.

create table if not exists public.profiles (
  id           uuid        primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is
  'One row per auth user. No contest data here — see the header note.';

-- RLS on, and crucially FORCE it: without force, the table owner (and any role
-- holding BYPASSRLS) skips the policies. Force makes the policies apply to the
-- owner too, so a future migration cannot quietly bypass them.
alter table public.profiles enable row level security;
alter table public.profiles force  row level security;

-- With RLS enabled and no policy, every statement is denied by default. The
-- three policies below are the complete access surface.

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- No DELETE policy on purpose: rule 4.3 forbids the agent running destructive
-- database commands, and profile removal should be an account-level action.
-- If deletion is ever required, add it as a separate reviewed migration.

-- --- updated_at -------------------------------------------------------------
-- Keeps updated_at honest without the client having to remember it. SECURITY
-- DEFINER plus a fixed search_path: without the latter, a caller could in
-- principle shadow `auth` and redirect the lookup.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

-- --- grants -----------------------------------------------------------------
-- PostgREST reaches tables as `anon` and `authenticated`; without a grant the
-- roles have no table privilege at all and every query fails with 42501
-- regardless of RLS.
--
-- Revoke first, then grant. Supabase's default privileges for the public schema
-- are `arwdDxtm` for anon and authenticated — that is ALL of them, including
-- DELETE and TRUNCATE — so a bare `grant select, insert, update` ADDS to the
-- existing set rather than narrowing it. Verified on this stack: after only
-- granting those three, `information_schema.role_table_grants` still reported
-- DELETE for authenticated, because the default ACL had already supplied it.
-- RLS still blocked the delete (0 rows, since no DELETE policy exists), but the
-- privilege itself was wider than intended. Explicit REVOKE makes the intent
-- hold at both layers.
revoke all on public.profiles from anon, authenticated;
grant select, insert, update on public.profiles to anon, authenticated;

grant usage on schema public to anon, authenticated;

-- The `to authenticated` clauses on every policy already deny anonymous callers,
-- so anon holds no usable path to this table. It is granted nothing further.