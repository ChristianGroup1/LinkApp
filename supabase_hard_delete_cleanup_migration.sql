-- Run once after switching from soft delete to hard delete.
-- It permanently removes records that were previously hidden with is_active = false.

-- Inactive meetings and everything under them.
delete from public.members
where meeting_id in (select id from public.meetings where is_active = false);

delete from public.members
where sunday_school_class_id in (
  select c.id
  from public.sunday_school_classes c
  join public.meetings m on m.id = c.meeting_id
  where m.is_active = false
);

delete from public.class_assignments
where class_id in (
  select c.id
  from public.sunday_school_classes c
  join public.meetings m on m.id = c.meeting_id
  where m.is_active = false
);

delete from public.invitations
where target_id in (
  select c.id
  from public.sunday_school_classes c
  join public.meetings m on m.id = c.meeting_id
  where m.is_active = false
);

delete from public.attendance_sessions
where class_id in (
  select c.id
  from public.sunday_school_classes c
  join public.meetings m on m.id = c.meeting_id
  where m.is_active = false
);

delete from public.sunday_school_classes
where meeting_id in (select id from public.meetings where is_active = false);

delete from public.meeting_assignments
where meeting_id in (select id from public.meetings where is_active = false);

delete from public.invitations
where target_id in (select id from public.meetings where is_active = false);

delete from public.attendance_sessions
where meeting_id in (select id from public.meetings where is_active = false);

delete from public.meetings
where is_active = false;

-- Inactive standalone classes and everything under them.
delete from public.members
where sunday_school_class_id in (
  select id from public.sunday_school_classes where is_active = false
);

delete from public.class_assignments
where class_id in (
  select id from public.sunday_school_classes where is_active = false
);

delete from public.invitations
where target_id in (
  select id from public.sunday_school_classes where is_active = false
);

delete from public.attendance_sessions
where class_id in (
  select id from public.sunday_school_classes where is_active = false
);

delete from public.sunday_school_classes
where is_active = false;

-- Inactive members.
delete from public.members
where is_active = false;
