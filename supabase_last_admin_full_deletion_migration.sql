-- Allows the verified delete-account Edge Function to remove an entire church
-- when the requester is its last active administrator.
-- Public tenant data is deleted in one database transaction. Auth users are
-- then removed by the Edge Function through Supabase Auth Admin API.

create or replace function public.delete_church_for_last_admin(
  p_requester_id uuid
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
  church_user_ids uuid[];
begin
  select p.church_id
  into target_church_id
  from public.profiles p
  where p.id = p_requester_id
    and p.is_active
    and p.role in ('church_admin', 'super_admin');

  if target_church_id is null then
    raise exception 'requester_is_not_active_admin';
  end if;

  -- Serialize tenant deletion with new profile inserts and lock all existing
  -- profiles before checking which active administrators remain.
  perform 1 from public.churches
  where id = target_church_id
  for update;
  perform 1 from public.profiles
  where church_id = target_church_id
  for update;

  if exists (
    select 1
    from public.profiles p
    where p.church_id = target_church_id
      and p.id <> p_requester_id
      and p.is_active
      and p.role in ('church_admin', 'super_admin')
  ) then
    raise exception 'another_active_admin_exists';
  end if;

  select coalesce(array_agg(p.id order by p.id), array[]::uuid[])
  into church_user_ids
  from public.profiles p
  where p.church_id = target_church_id;

  -- Delete deepest dependencies first so restrictive member target foreign
  -- keys cannot interrupt the tenant deletion halfway through.
  delete from public.attendance_records
  where church_id = target_church_id;
  delete from public.follow_ups
  where church_id = target_church_id;
  delete from public.attendance_sessions
  where church_id = target_church_id;
  delete from public.members
  where church_id = target_church_id;
  delete from public.class_assignments
  where church_id = target_church_id;
  delete from public.meeting_assignments
  where church_id = target_church_id;
  delete from public.invitations
  where church_id = target_church_id;
  delete from public.sunday_school_classes
  where church_id = target_church_id;
  delete from public.meetings
  where church_id = target_church_id;

  if to_regclass('public.support_tickets') is not null then
    execute 'delete from public.support_tickets where church_id = $1'
      using target_church_id;
  end if;
  if to_regclass('public.app_usage_events') is not null then
    execute 'delete from public.app_usage_events where church_id = $1'
      using target_church_id;
  end if;
  if to_regclass('public.admin_audit_logs') is not null then
    execute 'delete from public.admin_audit_logs where admin_user_id = any($1)'
      using church_user_ids;
  end if;

  delete from public.profiles
  where church_id = target_church_id;
  delete from public.churches
  where id = target_church_id;

  return church_user_ids;
end;
$$;

revoke all on function public.delete_church_for_last_admin(uuid)
from public, anon, authenticated;
grant execute on function public.delete_church_for_last_admin(uuid)
to service_role;

comment on function public.delete_church_for_last_admin(uuid) is
  'Transactionally deletes one church tenant after verifying its last active admin.';
