-- Bind invitation actions to the invited email address.
-- Run this file in Supabase SQL Editor before releasing the matching app.

begin;

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
begin
  select *
  into invite
  from public.invitations
  where id = invitation_id
    and is_used = false
    and declined_at is null;

  if not found then
    raise exception 'كود التفعيل غير صالح أو تم استخدامه مسبقاً.';
  end if;

  update public.profiles
  set church_id = invite.church_id,
      updated_at = now()
  where id = new_user_id;

  if invite.target_id is not null then
    if invite.role = 'class_leader'
       and invite.assignment_scope = 'meeting_classes'
       and exists (
         select 1 from public.meetings where id = invite.target_id
       ) then
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
    elsif invite.role = 'class_leader'
          and exists (
            select 1 from public.sunday_school_classes
            where id = invite.target_id
          ) then
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
    elsif invite.role = 'attendance_officer'
          and exists (
            select 1 from public.meetings where id = invite.target_id
          ) then
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

  -- A deleted target no longer blocks joining the church. The invitation is
  -- accepted without an assignment and an admin can assign a new task later.
  update public.invitations
  set is_used = true
  where id = invitation_id;
end;
$$;

create or replace function public.decline_invitation_by_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
  current_email text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول بنفس البريد الموجهة إليه الدعوة.';
  end if;

  select i.*
  into inv
  from public.invitations i
  where i.invite_token = btrim(p_token)
    and i.is_used = false
    and i.declined_at is null
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  select lower(btrim(u.email))
  into current_email
  from auth.users u
  where u.id = auth.uid();

  if nullif(lower(btrim(inv.email)), '') is null
     or current_email is distinct from lower(btrim(inv.email)) then
    raise exception 'هذه الدعوة موجهة إلى بريد إلكتروني مختلف. سجّل الدخول بالبريد المدعو.';
  end if;

  update public.invitations
  set declined_at = now()
  where id = inv.id;
end;
$$;

revoke all on function public.decline_invitation_by_token(text)
  from public, anon;
grant execute on function public.decline_invitation_by_token(text)
  to authenticated;

create or replace function public.accept_invitation_link(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
  current_email text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select i.*
  into inv
  from public.invitations i
  where i.invite_token = btrim(p_token)
    and i.is_used = false
    and i.declined_at is null
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  select lower(btrim(u.email))
  into current_email
  from auth.users u
  where u.id = auth.uid();

  if nullif(lower(btrim(inv.email)), '') is null
     or current_email is distinct from lower(btrim(inv.email)) then
    raise exception 'هذه الدعوة موجهة إلى بريد إلكتروني مختلف. سجّل الدخول بالبريد المدعو.';
  end if;

  update public.profiles
  set church_id = inv.church_id,
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'أكمل إنشاء حسابك أولاً من شاشة التسجيل.';
  end if;

  perform public.accept_invitation_assignment(inv.id, auth.uid());
  return inv.church_id;
end;
$$;

revoke all on function public.accept_invitation_link(text)
  from public, anon;
grant execute on function public.accept_invitation_link(text)
  to authenticated;

create or replace function public.register_invited_signup(
  profile_id uuid,
  invite_code text default null,
  invite_token text default null,
  profile_full_name text default null,
  profile_email text default null,
  profile_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
  normalized_full_name text := nullif(btrim(profile_full_name), '');
  profile_church_id uuid;
  normalized_code text := nullif(upper(btrim(invite_code)), '');
  normalized_token text := nullif(btrim(invite_token), '');
  current_email text;
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_full_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if normalized_code is null and normalized_token is null then
    raise exception 'رابط أو كود الدعوة مطلوب';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  select i.*
  into inv
  from public.invitations i
  where i.is_used = false
    and i.declined_at is null
    and (
      (normalized_token is not null and i.invite_token = normalized_token)
      or (normalized_code is not null and upper(btrim(i.code)) = normalized_code)
    )
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو تم استخدامها أو رفضها.';
  end if;

  if normalized_token is not null then
    select lower(btrim(u.email))
    into current_email
    from auth.users u
    where u.id = auth.uid();

    if nullif(lower(btrim(inv.email)), '') is null
       or current_email is distinct from lower(btrim(inv.email))
       or lower(btrim(profile_email)) is distinct from lower(btrim(inv.email)) then
      raise exception 'يجب إنشاء الحساب بنفس البريد الإلكتروني المكتوب في الدعوة.';
    end if;
  end if;

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    inv.church_id,
    normalized_full_name,
    inv.role,
    coalesce(current_email, nullif(lower(btrim(profile_email)), '')),
    nullif(btrim(profile_phone), '')
  )
  returning church_id into profile_church_id;

  perform public.accept_invitation_assignment(inv.id, profile_id);
  return profile_church_id;
end;
$$;

revoke all on function public.register_invited_signup(uuid, text, text, text, text, text)
  from public, anon;
grant execute on function public.register_invited_signup(uuid, text, text, text, text, text)
  to authenticated;

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
        'assignment_scope', i.assignment_scope,
        'can_take_attendance', i.can_take_attendance,
        'can_view_reports', i.can_view_reports,
        'invite_token', i.invite_token,
        'is_used', i.is_used,
        'declined_at', i.declined_at,
        'created_at', i.created_at,
        'target_exists', case
          when i.target_id is null then true
          when i.role = 'class_leader'
               and i.assignment_scope = 'meeting_classes'
            then exists (
              select 1 from public.meetings m where m.id = i.target_id
            )
          when i.role = 'class_leader'
            then exists (
              select 1 from public.sunday_school_classes s
              where s.id = i.target_id
            )
          when i.role = 'attendance_officer'
            then exists (
              select 1 from public.meetings m where m.id = i.target_id
            )
          else true
        end,
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

-- This helper is internal. Direct client execution could otherwise bypass the
-- email checks performed by the public invitation entry points above.
revoke all on function public.accept_invitation_assignment(uuid, uuid)
  from public, anon, authenticated;

commit;
