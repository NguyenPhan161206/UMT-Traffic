-- Ensure roles exist (in case 000002 didn't insert)
-- This migration safely inserts admin and student roles if missing

insert into public.roles (id, name, description) values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'admin', 'Administrator - full system access'),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'student', 'Student - take quiz, view own score')
on conflict (name) do nothing;
