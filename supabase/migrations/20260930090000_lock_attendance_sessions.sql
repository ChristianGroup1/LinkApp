alter table public.attendance_sessions
  add column if not exists is_locked boolean not null default false,
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by uuid;

create or replace function public.guard_attendance_session_lock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_is_church_admin boolean;
begin
  if tg_op = 'DELETE' then
    if old.is_locked and coalesce((select auth.role()), '') <> 'service_role' then
      raise exception 'attendance_session_locked' using errcode = '55000';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.is_locked or new.locked_at is not null or new.locked_by is not null then
      raise exception 'attendance_session_lock_is_managed' using errcode = '42501';
    end if;
    return new;
  end if;

  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.church_id = old.church_id
      and p.role = 'church_admin'::public.app_role
      and p.is_active
  ) into caller_is_church_admin;

  if new.meeting_id is distinct from old.meeting_id
    or new.class_id is distinct from old.class_id
    or new.session_date is distinct from old.session_date
    or new.week_number is distinct from old.week_number
    or new.title is distinct from old.title then
    if old.is_locked then
      raise exception 'attendance_session_locked' using errcode = '55000';
    end if;
  end if;

  if new.is_locked is distinct from old.is_locked then
    if new.is_locked then
      if not public.can_take_session_attendance(old.id) then
        raise exception 'attendance_permission_required' using errcode = '42501';
      end if;
      new.locked_at := now();
      new.locked_by := (select auth.uid());
    else
      if not caller_is_church_admin then
        raise exception 'church_admin_required_to_unlock' using errcode = '42501';
      end if;
      new.locked_at := null;
      new.locked_by := null;
    end if;
  elsif new.locked_at is distinct from old.locked_at
      or new.locked_by is distinct from old.locked_by then
    raise exception 'attendance_lock_metadata_is_managed' using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function public.guard_locked_attendance_records()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  locked boolean;
begin
  if tg_op = 'DELETE' then
    if coalesce((select auth.role()), '') = 'service_role' then
      return old;
    end if;

    select s.is_locked into locked
    from public.attendance_sessions s
    where s.id = old.session_id
    for share;
    if coalesce(locked, false) then
      raise exception 'attendance_session_locked' using errcode = '55000';
    end if;
    return old;
  end if;

  -- Lock the session row while checking it so a concurrent lock operation
  -- cannot race with an attendance write.
  select s.is_locked into locked
  from public.attendance_sessions s
  where s.id = new.session_id
  for share;

  if coalesce(locked, false) then
    raise exception 'attendance_session_locked' using errcode = '55000';
  end if;

  if tg_op = 'UPDATE' and old.session_id is distinct from new.session_id then
    select s.is_locked into locked
    from public.attendance_sessions s
    where s.id = old.session_id
    for share;
    if coalesce(locked, false) then
      raise exception 'attendance_session_locked' using errcode = '55000';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists attendance_sessions_guard_lock
  on public.attendance_sessions;
create trigger attendance_sessions_guard_lock
before insert or update or delete on public.attendance_sessions
for each row execute function public.guard_attendance_session_lock();

drop trigger if exists attendance_records_guard_locked_session
  on public.attendance_records;
create trigger attendance_records_guard_locked_session
before insert or update or delete on public.attendance_records
for each row execute function public.guard_locked_attendance_records();

create or replace function public.lock_attendance_session(target_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_session public.attendance_sessions;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;

  if not public.can_take_session_attendance(target_session_id) then
    raise exception 'attendance_permission_required' using errcode = '42501';
  end if;

  update public.attendance_sessions
  set is_locked = true
  where id = target_session_id
  returning * into updated_session;

  if not found then
    raise exception 'attendance_session_not_found' using errcode = 'P0002';
  end if;

  return to_jsonb(updated_session);
end;
$$;

create or replace function public.unlock_attendance_session(target_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_session public.attendance_sessions;
begin
  if not exists (
    select 1
    from public.attendance_sessions s
    join public.profiles p on p.church_id = s.church_id
    where s.id = target_session_id
      and p.id = (select auth.uid())
      and p.role = 'church_admin'::public.app_role
      and p.is_active
  ) then
    raise exception 'church_admin_required_to_unlock' using errcode = '42501';
  end if;

  update public.attendance_sessions
  set is_locked = false
  where id = target_session_id
  returning * into updated_session;

  if not found then
    raise exception 'attendance_session_not_found' using errcode = 'P0002';
  end if;

  return to_jsonb(updated_session);
end;
$$;

revoke all on function public.lock_attendance_session(uuid) from public, anon;
revoke all on function public.unlock_attendance_session(uuid) from public, anon;
grant execute on function public.lock_attendance_session(uuid) to authenticated;
grant execute on function public.unlock_attendance_session(uuid) to authenticated;
