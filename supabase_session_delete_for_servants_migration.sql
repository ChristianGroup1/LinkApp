-- Allow servants with take-attendance permission to delete their sessions.
drop policy if exists "sessions_delete_admin" on public.attendance_sessions;
drop policy if exists "sessions_delete_take_attendance" on public.attendance_sessions;

create policy "sessions_delete_take_attendance" on public.attendance_sessions
for delete using (
  public.is_church_admin(church_id)
  or public.can_take_session_attendance(id)
);
