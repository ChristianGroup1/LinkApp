-- Tighten attendance sheet creation permissions.
-- Run this after the assignment permissions migrations.

create or replace function public.create_attendance_session(
  target_meeting_id uuid,
  target_class_id uuid,
  target_session_date date,
  target_week_number integer,
  target_title text default null
)
returns public.attendance_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles%rowtype;
  saved_session public.attendance_sessions%rowtype;
begin
  select *
    into current_profile
    from public.profiles
    where id = auth.uid()
      and is_active;

  if current_profile.id is null then
    raise exception 'المستخدم الحالي غير مسجل أو غير مفعل';
  end if;

  if not exists (
    select 1
    from public.meetings m
    where m.id = target_meeting_id
      and m.church_id = current_profile.church_id
      and m.is_active
  ) then
    raise exception 'الاجتماع غير تابع لكنيستك أو غير مفعل';
  end if;

  if target_class_id is not null and not exists (
    select 1
    from public.sunday_school_classes c
    where c.id = target_class_id
      and c.meeting_id = target_meeting_id
      and c.church_id = current_profile.church_id
      and c.is_active
  ) then
    raise exception 'الفصل غير تابع لهذا الاجتماع';
  end if;

  if not (
    current_profile.role in ('super_admin', 'church_admin')
    or (
      target_class_id is not null
      and exists (
        select 1
        from public.class_assignments ca
        where ca.class_id = target_class_id
          and ca.user_id = current_profile.id
          and ca.can_take_attendance
      )
    )
    or (
      target_class_id is null
      and exists (
        select 1
        from public.meeting_assignments ma
        where ma.meeting_id = target_meeting_id
          and ma.user_id = current_profile.id
          and ma.can_take_attendance
      )
    )
  ) then
    raise exception 'ليس لديك صلاحية تسجيل حضور لهذا الاجتماع';
  end if;

  insert into public.attendance_sessions (
    church_id,
    meeting_id,
    class_id,
    session_date,
    week_number,
    title,
    created_by
  )
  values (
    current_profile.church_id,
    target_meeting_id,
    target_class_id,
    target_session_date,
    target_week_number,
    nullif(btrim(target_title), ''),
    current_profile.id
  )
  on conflict (church_id, meeting_id, class_id, session_date)
  do update
    set week_number = excluded.week_number,
        title = coalesce(excluded.title, attendance_sessions.title)
  returning * into saved_session;

  return saved_session;
end;
$$;

grant execute on function public.create_attendance_session(uuid, uuid, date, integer, text) to authenticated;
