-- `members_select_access` previously called can_access_member(id). During an
-- INSERT ... RETURNING request, that helper could not see the new row yet, so
-- PostgreSQL rejected an otherwise-authorized insert with SQLSTATE 42501.
-- Keep the same tenant and assignment rules, but evaluate them from NEW's row
-- values so PostgREST `.insert(...).select()` succeeds.
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
    )
  );
