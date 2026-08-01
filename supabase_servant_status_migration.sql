-- Safely suspend and restore servant access without deleting historical data.
-- Safe to run more than once.

create or replace function public.current_church_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select church_id
  from public.profiles
  where id = auth.uid()
    and is_active;
$$;

drop policy if exists "profiles_select_same_church" on public.profiles;
create policy "profiles_select_same_church" on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or church_id = public.current_church_id()
);

create or replace function public.admin_update_profile_status(
  target_user_id uuid,
  new_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile public.profiles%rowtype;
begin
  select * into target_profile
  from public.profiles
  where id = target_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;

  if not public.is_church_admin(target_profile.church_id) then
    raise exception 'غير مصرح بتعديل حالة الحساب';
  end if;

  if target_user_id = auth.uid() and not new_is_active then
    raise exception 'لا يمكنك إيقاف حسابك الحالي';
  end if;

  if target_profile.role = 'super_admin' and not new_is_active then
    raise exception 'لا يمكن إيقاف حساب المدير الرئيسي';
  end if;

  update public.profiles
  set is_active = new_is_active
  where id = target_user_id;
end;
$$;

grant execute on function public.admin_update_profile_status(uuid, boolean)
to authenticated;
