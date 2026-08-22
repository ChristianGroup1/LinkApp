begin;

-- Keep newly-created invitations internally consistent. The target table is
-- polymorphic, so PostgreSQL cannot express this with a regular foreign key.
create or replace function public.validate_invitation_target()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.target_id is null then
    return new;
  end if;

  if new.assignment_scope = 'class' then
    if not exists (
      select 1
      from public.sunday_school_classes c
      where c.id = new.target_id
        and c.church_id = new.church_id
        and c.is_active = true
    ) then
      raise exception 'الفصل المحدد غير موجود أو غير متاح.';
    end if;
    if new.role not in ('church_admin', 'super_admin') then
      new.role := 'class_leader';
    end if;
  elsif new.assignment_scope in ('meeting', 'meeting_classes') then
    if not exists (
      select 1
      from public.meetings m
      where m.id = new.target_id
        and m.church_id = new.church_id
        and m.is_active = true
    ) then
      raise exception 'الاجتماع المحدد غير موجود أو غير متاح.';
    end if;
    if new.role not in ('church_admin', 'super_admin') then
      new.role := case
        when new.assignment_scope = 'meeting' then 'attendance_officer'::public.app_role
        else 'class_leader'::public.app_role
      end;
    end if;
  else
    raise exception 'نوع المهمة المحدد في الدعوة غير صحيح.';
  end if;

  return new;
end;
$$;

drop trigger if exists validate_invitation_target_before_write
  on public.invitations;
create trigger validate_invitation_target_before_write
before insert or update of church_id, target_id, assignment_scope, role
on public.invitations
for each row execute function public.validate_invitation_target();

-- Direct deletes must also remove pending invitations. The existing cascade
-- RPCs already do this; these triggers cover deletes coming from any path.
create or replace function public.remove_meeting_pending_invitations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.invitations
  where target_id = old.id
    and assignment_scope in ('meeting', 'meeting_classes')
    and is_used = false;
  return old;
end;
$$;

drop trigger if exists remove_meeting_pending_invitations_after_delete
  on public.meetings;
create trigger remove_meeting_pending_invitations_after_delete
after delete on public.meetings
for each row execute function public.remove_meeting_pending_invitations();

create or replace function public.remove_class_pending_invitations()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.invitations
  where target_id = old.id
    and assignment_scope = 'class'
    and is_used = false;
  return old;
end;
$$;

drop trigger if exists remove_class_pending_invitations_after_delete
  on public.sunday_school_classes;
create trigger remove_class_pending_invitations_after_delete
after delete on public.sunday_school_classes
for each row execute function public.remove_class_pending_invitations();

-- Accept according to assignment_scope, not the display role. If an old
-- invitation already points to a deleted target, accept the church membership
-- without an assignment; an administrator can assign a current task later.
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
  class_row record;
  resolved_role public.app_role;
begin
  select *
  into invite
  from public.invitations
  where id = invitation_id
    and is_used = false
    and declined_at is null
  for update;

  if not found then
    raise exception 'كود التفعيل غير صالح أو تم استخدامه مسبقاً.';
  end if;

  resolved_role := case
    when invite.role in ('church_admin', 'super_admin') then invite.role
    when invite.assignment_scope = 'meeting' then 'attendance_officer'::public.app_role
    when invite.assignment_scope in ('class', 'meeting_classes') then 'class_leader'::public.app_role
    else invite.role
  end;

  update public.profiles
  set church_id = invite.church_id,
      role = resolved_role,
      updated_at = now()
  where id = new_user_id;

  if invite.target_id is not null then
    if invite.assignment_scope = 'meeting_classes'
       and exists (
         select 1 from public.meetings m
         where m.id = invite.target_id
           and m.church_id = invite.church_id
           and m.is_active = true
       ) then
      for class_row in
        select id
        from public.sunday_school_classes
        where meeting_id = invite.target_id
          and church_id = invite.church_id
          and is_active = true
      loop
        insert into public.class_assignments (
          church_id, class_id, user_id,
          can_take_attendance, can_view_reports
        ) values (
          invite.church_id, class_row.id, new_user_id,
          coalesce(invite.can_take_attendance, true),
          coalesce(invite.can_view_reports, true)
        )
        on conflict (class_id, user_id) do update set
          can_take_attendance = excluded.can_take_attendance,
          can_view_reports = excluded.can_view_reports;
      end loop;
    elsif invite.assignment_scope = 'class'
       and exists (
         select 1 from public.sunday_school_classes c
         where c.id = invite.target_id
           and c.church_id = invite.church_id
           and c.is_active = true
       ) then
      insert into public.class_assignments (
        church_id, class_id, user_id,
        can_take_attendance, can_view_reports
      ) values (
        invite.church_id, invite.target_id, new_user_id,
        coalesce(invite.can_take_attendance, true),
        coalesce(invite.can_view_reports, true)
      )
      on conflict (class_id, user_id) do update set
        can_take_attendance = excluded.can_take_attendance,
        can_view_reports = excluded.can_view_reports;
    elsif invite.assignment_scope = 'meeting'
       and exists (
         select 1 from public.meetings m
         where m.id = invite.target_id
           and m.church_id = invite.church_id
           and m.is_active = true
       ) then
      insert into public.meeting_assignments (
        church_id, meeting_id, user_id,
        can_take_attendance, can_view_reports
      ) values (
        invite.church_id, invite.target_id, new_user_id,
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

revoke all on function public.accept_invitation_assignment(uuid, uuid)
  from public, anon;
grant execute on function public.accept_invitation_assignment(uuid, uuid)
  to authenticated;

-- Tell the client whether an old pending invitation still has a live target.
create or replace function public.get_my_received_invitations()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, auth
as $$
declare
  user_email text;
  result jsonb;
begin
  user_email := lower(btrim(auth.jwt() ->> 'email'));
  if user_email is null or user_email = '' then
    return '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', i.id,
        'church_id', i.church_id,
        'full_name', i.full_name,
        'email', i.email,
        'role', i.role,
        'target_id', i.target_id,
        'assignment_scope', i.assignment_scope,
        'target_exists', case
          when i.target_id is null then true
          when i.assignment_scope = 'class' then exists (
            select 1 from public.sunday_school_classes c
            where c.id = i.target_id and c.church_id = i.church_id
          )
          when i.assignment_scope in ('meeting', 'meeting_classes') then exists (
            select 1 from public.meetings m
            where m.id = i.target_id and m.church_id = i.church_id
          )
          else false
        end,
        'can_take_attendance', i.can_take_attendance,
        'can_view_reports', i.can_view_reports,
        'invite_token', i.invite_token,
        'is_used', i.is_used,
        'declined_at', i.declined_at,
        'created_at', i.created_at,
        'churches', jsonb_build_object(
          'name', c.name,
          'name_ar', c.name_ar
        )
      ) order by i.created_at desc
    ),
    '[]'::jsonb
  )
  into result
  from public.invitations i
  join public.churches c on c.id = i.church_id
  where lower(btrim(i.email)) = user_email;

  return result;
end;
$$;

revoke all on function public.get_my_received_invitations()
  from public, anon;
grant execute on function public.get_my_received_invitations()
  to authenticated;

commit;
