-- Avoid recursive RLS evaluation between member_meeting_assignments and
-- members. can_access_member is SECURITY DEFINER and preserves the same
-- tenant and member-access checks without querying members through its RLS
-- policy while the assignment policy is being evaluated.

drop policy if exists member_meeting_assignments_insert
  on public.member_meeting_assignments;
create policy member_meeting_assignments_insert
on public.member_meeting_assignments
for insert to authenticated
with check (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and public.can_access_member(member_id)
);

drop policy if exists member_meeting_assignments_update
  on public.member_meeting_assignments;
create policy member_meeting_assignments_update
on public.member_meeting_assignments
for update to authenticated
using (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and public.can_access_member(member_id)
)
with check (
  church_id = (select public.current_church_id())
  and public.can_take_meeting_attendance(meeting_id)
  and public.can_access_member(member_id)
);
