-- Seed admin user
-- IMPORTANT: This migration assumes an admin user already exists in auth.users
-- Created via Supabase Dashboard → Auth → Add user (admin@gmail.com)
--
-- If admin user doesn't exist, manually create it first:
-- 1. Supabase Dashboard → Auth → Users
-- 2. Click "Add user" → Email: admin@gmail.com, Password: [your password]
-- 3. Then run this migration to assign the admin role

-- Assign admin role to the admin user (if not already assigned)
insert into public.user_roles (user_id, role_id)
select id, (select id from public.roles where name = 'admin')
from auth.users
where email = 'admin@gmail.com'
on conflict (user_id, role_id) do nothing;
