create or replace function public.accept_invitation_assignment(
  invitation_id uuid,
  new_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  invite record;
  profile_church_id uuid;
  class_row record;
begin
  select *
  into invite
  from public.invitations
  where id = invitation_id
    and is_used = false;

  if not found then
    raise exception 'كود التفعيل غير صالح أو تم استخدامه مسبقاً.';
  end if;

  select church_id
  into profile_church_id
  from public.profiles
  where id = new_user_id;

  if profile_church_id is null or profile_church_id <> invite.church_id then
    raise exception 'ملف الخادم غير مربوط بنفس الكنيسة.';
  end if;

  if invite.target_id is not null then
    if invite.role = 'class_leader' and invite.assignment_scope = 'meeting_classes' then
      for class_row in
        select id
        from public.sunday_school_classes
        where meeting_id = invite.target_id
          and is_active = true
      loop
        insert into public.class_assignments (
          church_id,
          class_id,
          user_id,
          can_take_attendance,
          can_view_reports
        )
        values (
          invite.church_id,
          class_row.id,
          new_user_id,
          coalesce(invite.can_take_attendance, true),
          coalesce(invite.can_view_reports, true)
        )
        on conflict (class_id, user_id) do update set
          can_take_attendance = excluded.can_take_attendance,
          can_view_reports = excluded.can_view_reports;
      end loop;
    elsif invite.role = 'class_leader' then
      insert into public.class_assignments (
        church_id,
        class_id,
        user_id,
        can_take_attendance,
        can_view_reports
      )
      values (
        invite.church_id,
        invite.target_id,
        new_user_id,
        coalesce(invite.can_take_attendance, true),
        coalesce(invite.can_view_reports, true)
      )
      on conflict (class_id, user_id) do update set
        can_take_attendance = excluded.can_take_attendance,
        can_view_reports = excluded.can_view_reports;
    elsif invite.role = 'attendance_officer' then
      insert into public.meeting_assignments (
        church_id,
        meeting_id,
        user_id,
        can_take_attendance,
        can_view_reports
      )
      values (
        invite.church_id,
        invite.target_id,
        new_user_id,
        coalesce(invite.can_take_attendance, true),
        coalesce(invite.can_view_reports, true)
      )
      on conflict (meeting_id, user_id) do update set
        can_take_attendance = excluded.can_take_attendance,
        can_view_reports = excluded.can_view_reports;
    end if;
  end if;

  update public.invitations
  set is_used = true
  where id = invitation_id;
end;
$$;

grant execute on function public.accept_invitation_assignment(uuid, uuid) to anon, authenticated;
