-- Shared weekly attendance reminder time for every servant assigned to a
-- meeting or one of its classes. The value is minutes after local midnight.
-- Safe to run more than once.
alter table public.meetings
  add column if not exists attendance_reminder_minutes integer;

alter table public.meetings
  drop constraint if exists meetings_attendance_reminder_minutes_check;

alter table public.meetings
  add constraint meetings_attendance_reminder_minutes_check
  check (
    attendance_reminder_minutes is null
    or attendance_reminder_minutes between 0 and 1439
  );
