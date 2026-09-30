-- 000002_roles_and_permissions.sql
-- Dynamic role-based access control (RBAC)
-- Admin can modify permissions without code changes

-- =====================================================
-- 1. ROLES TABLE (Không đổi)
-- =====================================================
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  created_at timestamptz default now()
);

comment on table public.roles is 'Static roles: student, admin. For future extensibility.';

-- =====================================================
-- 2. USER_ROLES (Gán role cho người dùng)
-- =====================================================
create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  granted_by uuid references auth.users(id), -- Who assigned this role
  created_at timestamptz default now(),
  unique(user_id, role_id)
);

comment on table public.user_roles is 'Maps users to roles. Soft RLS: anyone can read (for UI checks), but only admin can write.';

-- =====================================================
-- 3. ROLE_PERMISSIONS (Động - Admin chỉnh sửa)
-- =====================================================
create table public.role_permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles(id) on delete cascade,
  resource text not null, -- 'quiz_questions', 'submissions', 'users', etc.
  action text not null,   -- 'create', 'read', 'update', 'delete', 'read_own'
  created_at timestamptz default now(),
  unique(role_id, resource, action)
);

comment on table public.role_permissions is 'DYNAMIC: Admin UI lets you add/remove permissions without code changes.';

-- =====================================================
-- 4. INSERT DEFAULT ROLES
-- =====================================================
insert into public.roles (id, name, description) values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'admin', 'Administrator - full system access'),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'student', 'Student - take quiz, view own score');

-- =====================================================
-- 5. ADMIN PERMISSIONS (Full access)
-- =====================================================
insert into public.role_permissions (role_id, resource, action) values
  -- Users & Roles
  ('10000000-0000-0000-0000-000000000001'::uuid, 'users', 'read'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'users', 'update'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'user_roles', 'create'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'user_roles', 'read'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'user_roles', 'delete'),
  -- Quiz Questions
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_questions', 'create'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_questions', 'read'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_questions', 'update'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_questions', 'delete'),
  -- Submissions & Scoring
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_submissions', 'read'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'quiz_submissions', 'update'),
  -- Permissions Management
  ('10000000-0000-0000-0000-000000000001'::uuid, 'role_permissions', 'read'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'role_permissions', 'create'),
  ('10000000-0000-0000-0000-000000000001'::uuid, 'role_permissions', 'delete');

-- =====================================================
-- 6. STUDENT PERMISSIONS (Minimal access)
-- =====================================================
insert into public.role_permissions (role_id, resource, action) values
  -- View available questions
  ('10000000-0000-0000-0000-000000000002'::uuid, 'quiz_questions', 'read'),
  -- Create & read own submissions
  ('10000000-0000-0000-0000-000000000002'::uuid, 'quiz_submissions', 'create'),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'quiz_submissions', 'read_own');

-- =====================================================
-- 7. RLS POLICIES (Enforce permissions)
-- =====================================================

-- roles table: Anyone can read (for UI dropdowns), but only for reference
alter table public.roles enable row level security;
create policy "roles_select_all"
  on public.roles for select
  to authenticated
  using (true); -- Public visibility for UI

-- user_roles: Read all (UI needs to check roles), write only by admin
alter table public.user_roles enable row level security;
create policy "user_roles_select_all"
  on public.user_roles for select
  to authenticated
  using (true); -- All users can check roles

create policy "user_roles_insert_admin_only"
  on public.user_roles for insert
  to authenticated
  with check (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

create policy "user_roles_delete_admin_only"
  on public.user_roles for delete
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

-- role_permissions: Read all (UI needs to show), write only by admin
alter table public.role_permissions enable row level security;
create policy "role_permissions_select_all"
  on public.role_permissions for select
  to authenticated
  using (true);

create policy "role_permissions_write_admin_only"
  on public.role_permissions for insert
  to authenticated
  with check (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

create policy "role_permissions_delete_admin_only"
  on public.role_permissions for delete
  to authenticated
  using (
    exists (
      select 1 from public.user_roles ur
      join public.roles r on ur.role_id = r.id
      where ur.user_id = auth.uid() and r.name = 'admin'
    )
  );

-- =====================================================
-- 8. GRANTS (PostgREST access)
-- =====================================================
revoke all on public.roles from anon, authenticated;
grant select on public.roles to authenticated;

revoke all on public.user_roles from anon, authenticated;
grant select, insert, delete on public.user_roles to authenticated;

revoke all on public.role_permissions from anon, authenticated;
grant select, insert, delete on public.role_permissions to authenticated;

grant usage on schema public to authenticated;
