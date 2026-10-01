-- Create profile on auth signup
create or replace function public.handle_new_user()
returns trigger as $$
declare
  student_role_id uuid;
begin
  -- Insert profile (email is in auth.users, no need to duplicate)
  insert into public.profiles (id, display_name)
  values (new.id, '')
  on conflict (id) do nothing;

  -- Get student role id
  select id into student_role_id from public.roles where name = 'student' limit 1;

  -- Assign student role by default
  if student_role_id is not null then
    insert into public.user_roles (user_id, role_id)
    values (new.id, student_role_id)
    on conflict (user_id, role_id) do nothing;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Trigger on auth.users table
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute procedure public.handle_new_user();
