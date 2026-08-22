begin;

-- Shared church records must survive account deletion. Attribution columns
-- become NULL when their author account is removed.
alter table public.meetings
  drop constraint if exists meetings_created_by_fkey;
alter table public.meetings
  add constraint meetings_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;

alter table public.class_assignments
  drop constraint if exists class_assignments_assigned_by_fkey;
alter table public.class_assignments
  add constraint class_assignments_assigned_by_fkey
  foreign key (assigned_by) references auth.users(id) on delete set null;

alter table public.meeting_assignments
  drop constraint if exists meeting_assignments_assigned_by_fkey;
alter table public.meeting_assignments
  add constraint meeting_assignments_assigned_by_fkey
  foreign key (assigned_by) references auth.users(id) on delete set null;

alter table public.attendance_sessions
  drop constraint if exists attendance_sessions_created_by_fkey;
alter table public.attendance_sessions
  add constraint attendance_sessions_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;

alter table public.attendance_records
  drop constraint if exists attendance_records_recorded_by_fkey;
alter table public.attendance_records
  add constraint attendance_records_recorded_by_fkey
  foreign key (recorded_by) references auth.users(id) on delete set null;

alter table public.follow_ups
  drop constraint if exists follow_ups_created_by_fkey;
alter table public.follow_ups
  add constraint follow_ups_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;

-- Audit entries are immutable historical records. Keep the actor UUID even
-- after the corresponding Auth user has been deleted.
alter table if exists public.admin_audit_logs
  drop constraint if exists admin_audit_logs_admin_user_id_fkey;

commit;
