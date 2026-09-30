# Admin Setup Guide

## Create Admin Account

### Step 1: Create User in Supabase Auth
1. Go to Supabase Dashboard → **Auth** → **Users**
2. Click **"Add user"**
3. Enter:
   - **Email:** `admin@example.com` (or your admin email)
   - **Password:** `Admin1234!` (or secure password)
4. Click **"Create user"**

### Step 2: Promote User to Admin Role
Run this SQL in Supabase → **SQL Editor**:

```sql
INSERT INTO public.user_roles (user_id, role_id)
SELECT id, (SELECT id FROM public.roles WHERE name = 'admin')
FROM auth.users WHERE email = 'admin@example.com'
ON CONFLICT (user_id, role_id) DO NOTHING;
```

### Step 3: Login & Access Admin Dashboard
1. Go to app: `http://localhost:5173`
2. Login with admin email/password
3. You'll see **Admin Dashboard** instead of quiz

## Admin Dashboard Features

- **📝 Quản lý câu hỏi** (Manage Questions): Create/edit/delete quiz questions
- **✓ Kết quả thi** (Results): View all student submissions and scores
- **👥 Quản lý học sinh** (Manage Students): View registered students
- **🔐 Quyền truy cập** (Permissions): Manage role-based permissions dynamically

## Dynamic Permissions

Admin can add/remove permissions without code changes:

```sql
-- Example: Allow students to see their own submissions
INSERT INTO public.role_permissions (role_id, resource, action)
SELECT id, 'quiz_submissions', 'read_own'
FROM public.roles WHERE name = 'student'
ON CONFLICT DO NOTHING;
```

## Test Accounts

- **Admin:** admin@example.com / Admin1234!
- **Student:** student@example.com / Student1234!

Both accounts will auto-create profiles on first login.
