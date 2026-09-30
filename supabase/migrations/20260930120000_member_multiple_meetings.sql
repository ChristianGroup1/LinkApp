-- Keep one member profile while allowing direct membership in more than one
-- meeting. The existing members.meeting_id remains the primary assignment for
-- compatibility with current offline data and imports.
create table if not exists public.member_meeting_assignments (
  church_id uuid not null references public.churches(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  sunday_school_class_id uuid references public.sunday_school_classes(id) on delete cascade,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (member_id, meeting_id),
  constraint member_meeting_assignment_scope_check
    check (sunday_school_class_id is null or is_primary)
);

create index if not exists idx_member_meeting_assignments_meeting
  on public.member_meeting_assignments (meeting_id, member_id);
create unique index if not exists idx_member_meeting_assignments_one_primary
  on public.member_meeting_assignments (member_id)
  where is_primary;

insert into public.member_meeting_assignments (
  church_id, member_id, meeting_id, sunday_school_class_id, is_primary
)
select
  m.church_id,
  m.id,
  coalesce(c.meeting_id, m.meeting_id),
  case when m.scope = 'sunday_school_class' then m.sunday_school_class_id end,
  true
from public.members m
left join public.sunday_school_classes c
  on c.id = m.sunday_school_class_id
where (m.scope = 'sunday_school_class' and m.sunday_school_class_id is not null)
   or (m.scope = 'meeting' and m.meeting_id is not null)
on conflict (member_id, meeting_id) do update
  set sunday_school_class_id = excluded.sunday_school_class_id,
      is_primary = true;

create or replace function public.sync_primary_member_meeting_assignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_meeting_id uuid;
  target_class_id uuid;
begin
  if tg_op = 'UPDATE'
     and new.scope is not distinct from old.scope
     and new.meeting_id is not distinct from old.meeting_id
     and new.sunday_school_class_id is not distinct from old.sunday_school_class_id then
    return new;
  end if;

  delete from public.member_meeting_assignments
  where member_id = new.id and is_primary;

  if new.scope = 'sunday_school_class' and new.sunday_school_class_id is not null then
    select c.meeting_id into target_meeting_id
    from public.sunday_school_classes c
    where c.id = new.sunday_school_class_id;
    target_class_id := new.sunday_school_class_id;
  elsif new.scope = 'meeting' then
    target_meeting_id := new.meeting_id;
    target_class_id := null;
  else
    target_meeting_id := null;
    target_class_id := null;
  end if;

  if target_meeting_id is not null then
    insert into public.member_meeting_assignments (
      church_id, member_id, meeting_id, sunday_school_class_id, is_primary
    ) values (
      new.church_id, new.id, target_meeting_id, target_class_id, true
    )
    on conflict (member_id, meeting_id) do update
      set sunday_school_class_id = excluded.sunday_school_class_id,
          is_primary = true;
  end if;

  return new;
end;
$$;

drop trigger if exists sync_primary_member_meeting_assignment on public.members;
create trigger sync_primary_member_meeting_assignment
after insert or update of scope, meeting_id, sunday_school_class_id
on public.members
for each row execute function public.sync_primary_member_meeting_assignment();

alter table public.member_meeting_assignments enable row level security;
grant select, insert, update on public.member_meeting_assignments to authenticated;

drop policy if exists member_meeting_assignments_select on public.member_meeting_assignments;
create policy member_meeting_assignments_select
on public.member_meeting_assignments
for select to authenticated
using (
  church_id = (select public.current_church_id())
  and public.can_access_meeting(meeting_id)
);

drop policy if exists member_meeting_assignments_insert on public.member_meeting_assignments;
create policy member_meeting_assignments_insert
on public.member_meeting_assignments
for insert to authenticated
with check (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and exists (
    select 1 from public.members m
    where m.id = member_meeting_assignments.member_id
      and m.church_id = member_meeting_assignments.church_id
  )
);

drop policy if exists member_meeting_assignments_update on public.member_meeting_assignments;
create policy member_meeting_assignments_update
on public.member_meeting_assignments
for update to authenticated
using (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and exists (
    select 1 from public.members m
    where m.id = member_meeting_assignments.member_id
      and m.church_id = member_meeting_assignments.church_id
  )
)
with check (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and exists (
    select 1 from public.members m
    where m.id = member_meeting_assignments.member_id
      and m.church_id = member_meeting_assignments.church_id
  )
);

drop policy if exists members_select_access on public.members;
create policy members_select_access on public.members
for select to authenticated
using (
  church_id = (select public.current_church_id())
  and (
    public.is_church_admin(church_id)
    or (
      sunday_school_class_id is not null
      and public.can_access_class(sunday_school_class_id)
    )
    or (
      meeting_id is not null
      and public.can_access_meeting(meeting_id)
    )
    or exists (
      select 1
      from public.member_meeting_assignments mma
      where mma.member_id = members.id
        and mma.sunday_school_class_id is null
        and public.can_access_meeting(mma.meeting_id)
    )
  )
);
