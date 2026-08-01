-- Remove service years from an existing Link Supabase database.
-- Run this once in Supabase SQL Editor after backing up the database.

begin;

drop view if exists public.member_attendance_stats cascade;
drop view if exists public.member_service_year_attendance_stats cascade;

drop function if exists public.create_attendance_session(
  uuid,
  uuid,
  uuid,
  date,
  integer,
  text
) cascade;

alter table if exists public.attendance_sessions
  drop constraint if exists sessions_unique_slot;

-- If the same meeting/class/date exists in more than one old service year,
-- keep the oldest session and move non-conflicting attendance records to it.
-- This uses CTEs instead of a temporary table so it works reliably in Supabase SQL Editor.
update public.attendance_records r
set session_id = d.keeper_id
from (
  with ranked as (
    select
      id,
      first_value(id) over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as keeper_id,
      row_number() over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as rn
    from public.attendance_sessions
  )
  select id as duplicate_id, keeper_id
  from ranked
  where rn > 1
) d
where r.session_id = d.duplicate_id
  and not exists (
    select 1
    from public.attendance_records existing
    where existing.session_id = d.keeper_id
      and existing.member_id = r.member_id
  );

delete from public.attendance_records r
using (
  with ranked as (
    select
      id,
      first_value(id) over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as keeper_id,
      row_number() over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as rn
    from public.attendance_sessions
  )
  select id as duplicate_id, keeper_id
  from ranked
  where rn > 1
) d
where r.session_id = d.duplicate_id;

delete from public.attendance_sessions s
using (
  with ranked as (
    select
      id,
      first_value(id) over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as keeper_id,
      row_number() over (
        partition by church_id, meeting_id, class_id, session_date
        order by created_at, id
      ) as rn
    from public.attendance_sessions
  )
  select id as duplicate_id, keeper_id
  from ranked
  where rn > 1
) d
where s.id = d.duplicate_id;

alter table if exists public.attendance_sessions
  drop column if exists service_year_id;

alter table if exists public.attendance_sessions
  add constraint sessions_unique_slot
  unique nulls not distinct (church_id, meeting_id, class_id, session_date);

do $$
begin
  if to_regclass('public.service_years') is not null then
    drop policy if exists "service_years_select" on public.service_years;
    drop policy if exists "service_years_admin_manage" on public.service_years;
  end if;
end $$;

drop table if exists public.service_years cascade;

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
      )
    )
    or (
      target_class_id is null
      and exists (
        select 1
        from public.meeting_assignments ma
        where ma.meeting_id = target_meeting_id
          and ma.user_id = current_profile.id
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

create or replace view public.member_attendance_stats as
select
  m.id as member_id,
  m.full_name,
  m.church_id,
  m.scope,
  m.sunday_school_class_id,
  m.meeting_id,
  count(r.id) as recorded_weeks,
  count(r.id) filter (where r.status = 'present') as present_weeks,
  count(r.id) filter (where r.status = 'absent') as absent_weeks,
  count(r.id) filter (where r.status = 'excused') as excused_weeks,
  coalesce(
    round(
      (count(r.id) filter (where r.status = 'present')::numeric / nullif(count(r.id), 0)) * 100,
      2
    ),
    0
  ) as attendance_percentage
from public.members m
left join public.attendance_records r on r.member_id = m.id
left join public.attendance_sessions s on s.id = r.session_id
where m.is_active
group by m.id, m.full_name, m.church_id, m.scope, m.sunday_school_class_id, m.meeting_id;

grant execute on function public.create_attendance_session(uuid, uuid, date, integer, text) to authenticated;

commit;
