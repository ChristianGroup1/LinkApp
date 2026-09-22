-- Super-admin-only tenant deletion used by the protected Link Control panel.
-- The caller deletes the returned Auth users through the Auth Admin API.

create or replace function public.admin_delete_church_tenant(
  p_church_id uuid
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  church_user_ids uuid[];
begin
  perform 1 from public.churches where id = p_church_id for update;
  if not found then
    raise exception 'church_not_found';
  end if;

  select coalesce(array_agg(id order by id), array[]::uuid[])
  into church_user_ids
  from public.profiles
  where church_id = p_church_id;

  delete from public.attendance_records where church_id = p_church_id;
  delete from public.follow_ups where church_id = p_church_id;
  delete from public.attendance_sessions where church_id = p_church_id;
  delete from public.members where church_id = p_church_id;
  delete from public.class_assignments where church_id = p_church_id;
  delete from public.meeting_assignments where church_id = p_church_id;
  delete from public.invitations where church_id = p_church_id;
  delete from public.sunday_school_classes where church_id = p_church_id;
  delete from public.meetings where church_id = p_church_id;

  if to_regclass('public.support_tickets') is not null then
    execute 'delete from public.support_tickets where church_id = $1' using p_church_id;
  end if;
  if to_regclass('public.app_usage_events') is not null then
    execute 'delete from public.app_usage_events where church_id = $1' using p_church_id;
  end if;
  if to_regclass('public.admin_audit_logs') is not null then
    execute 'delete from public.admin_audit_logs where admin_user_id = any($1)' using church_user_ids;
  end if;

  delete from public.profiles where church_id = p_church_id;
  delete from public.churches where id = p_church_id;
  return church_user_ids;
end;
$$;

revoke all on function public.admin_delete_church_tenant(uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_church_tenant(uuid) to service_role;

-- Deletes service records personally created or recorded by one account.
-- Meetings, members, and other shared service structure intentionally remain.
create or replace function public.admin_delete_user_service_data(
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- A session created by this account and every attendance record under it
  -- are removed. Records personally marked by the account are removed too.
  delete from public.attendance_records where recorded_by = p_user_id;
  delete from public.attendance_sessions where created_by = p_user_id;

  -- Follow-ups are service work assigned to or created by this account.
  delete from public.follow_ups
  where created_by = p_user_id or responsible_user_id = p_user_id;

  if to_regclass('public.support_tickets') is not null then
    execute 'delete from public.support_tickets where user_id = $1' using p_user_id;
  end if;
  if to_regclass('public.app_usage_events') is not null then
    execute 'delete from public.app_usage_events where user_id = $1' using p_user_id;
  end if;
  if to_regclass('public.admin_audit_logs') is not null then
    execute 'delete from public.admin_audit_logs where admin_user_id = $1' using p_user_id;
  end if;
end;
$$;

revoke all on function public.admin_delete_user_service_data(uuid) from public, anon, authenticated;
grant execute on function public.admin_delete_user_service_data(uuid) to service_role;
