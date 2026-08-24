-- ============================================================
-- Link: Security hardening + bug fixes migration
-- Run in Supabase SQL Editor on existing projects.
-- ============================================================

-- ---------- 1. Secure church access ----------
alter table public.churches enable row level security;

drop policy if exists "churches_select_same_church" on public.churches;
create policy "churches_select_same_church" on public.churches
for select to authenticated
using (id = public.current_church_id());

drop policy if exists "churches_admin_update" on public.churches;
create policy "churches_admin_update" on public.churches
for update to authenticated
using (public.is_church_admin(id))
with check (public.is_church_admin(id));

-- ---------- 2. Lock down invitations ----------
drop policy if exists "invitations_public_code_lookup" on public.invitations;

create or replace function public.validate_invitation_code(invite_code text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  inv record;
begin
  select id, church_id, role
  into inv
  from public.invitations
  where upper(btrim(code)) = upper(btrim(invite_code))
    and is_used = false
  limit 1;

  if not found then
    return jsonb_build_object('valid', false);
  end if;

  return jsonb_build_object(
    'valid', true,
    'invitation_id', inv.id,
    'church_id', inv.church_id,
    'role', inv.role
  );
end;
$$;

grant execute on function public.validate_invitation_code(text) to anon, authenticated;

-- ---------- 3. Secure signup RPCs ----------
create or replace function public.register_new_church_signup(
  profile_id uuid,
  church_name text,
  profile_full_name text,
  profile_email text,
  profile_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_name text := nullif(btrim(church_name), '');
  normalized_full_name text := nullif(btrim(profile_full_name), '');
  target_church_id uuid;
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_name is null then
    raise exception 'اسم الكنيسة مطلوب';
  end if;

  if normalized_full_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  -- A church name is display-only and is never an authorization boundary.
  -- Every new-church signup receives a fresh tenant even when another church
  -- has exactly the same Arabic or English name.
  insert into public.churches (name, name_ar, slug)
  values (
    normalized_name,
    normalized_name,
    'church-' || replace(gen_random_uuid()::text, '-', '')
  )
  returning id into target_church_id;

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    target_church_id,
    normalized_full_name,
    'church_admin',
    nullif(btrim(profile_email), ''),
    nullif(btrim(profile_phone), '')
  );

  return target_church_id;
end;
$$;

create or replace function public.register_invited_signup(
  profile_id uuid,
  invite_code text,
  profile_full_name text,
  profile_email text,
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
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_full_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  select *
  into inv
  from public.invitations
  where upper(btrim(code)) = upper(btrim(invite_code))
    and is_used = false
  limit 1;

  if not found then
    raise exception 'كود التفعيل غير صالح أو تم استخدامه مسبقاً.';
  end if;

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    inv.church_id,
    normalized_full_name,
    inv.role,
    nullif(btrim(profile_email), ''),
    nullif(btrim(profile_phone), '')
  )
  returning church_id into profile_church_id;

  perform public.accept_invitation_assignment(inv.id, profile_id);

  return profile_church_id;
end;
$$;

revoke all on function public.register_new_church_signup(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.register_new_church_signup(uuid, text, text, text, text)
  to authenticated;

revoke all on function public.register_invited_signup(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.register_invited_signup(uuid, text, text, text, text)
  to authenticated;

revoke all on function public.ensure_church(text) from public, anon, authenticated;
revoke all on function public.create_signup_profile(uuid, uuid, text, public.app_role, text, text)
  from public, anon, authenticated;

-- ---------- 4. Cascade delete RPCs ----------
create or replace function public.delete_sunday_school_class_cascade(target_class_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
begin
  select church_id into target_church_id
  from public.sunday_school_classes
  where id = target_class_id;

  if not found then
    return;
  end if;

  if not public.is_church_admin(target_church_id) then
    raise exception 'غير مصرح بحذف هذا الفصل';
  end if;

  delete from public.follow_ups
  where member_id in (
    select id from public.members where sunday_school_class_id = target_class_id
  );

  delete from public.attendance_records
  where member_id in (
    select id from public.members where sunday_school_class_id = target_class_id
  );

  delete from public.members where sunday_school_class_id = target_class_id;
  delete from public.class_assignments where class_id = target_class_id;
  delete from public.invitations where target_id = target_class_id;
  delete from public.attendance_sessions where class_id = target_class_id;
  delete from public.sunday_school_classes where id = target_class_id;
end;
$$;

create or replace function public.delete_meeting_cascade(target_meeting_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
  class_row record;
  member_row record;
begin
  select church_id into target_church_id
  from public.meetings
  where id = target_meeting_id;

  if not found then
    return;
  end if;

  if not public.is_church_admin(target_church_id) then
    raise exception 'غير مصرح بحذف هذا الاجتماع';
  end if;

  for class_row in
    select id from public.sunday_school_classes where meeting_id = target_meeting_id
  loop
    perform public.delete_sunday_school_class_cascade(class_row.id);
  end loop;

  for member_row in
    select id from public.members where meeting_id = target_meeting_id
  loop
    delete from public.follow_ups where member_id = member_row.id;
    delete from public.attendance_records where member_id = member_row.id;
    delete from public.members where id = member_row.id;
  end loop;

  delete from public.meeting_assignments where meeting_id = target_meeting_id;
  delete from public.invitations where target_id = target_meeting_id;
  delete from public.attendance_sessions where meeting_id = target_meeting_id;
  delete from public.meetings where id = target_meeting_id;
end;
$$;

grant execute on function public.delete_sunday_school_class_cascade(uuid) to authenticated;
grant execute on function public.delete_meeting_cascade(uuid) to authenticated;

-- ---------- 5. Secure reports view ----------
drop view if exists public.member_attendance_stats cascade;

create view public.member_attendance_stats
with (security_invoker = true) as
select
  m.id as member_id,
  m.full_name,
  m.church_id,
  m.scope,
  m.sunday_school_class_id,
  m.meeting_id,
  count(r.id) as recorded_weeks,
  count(r.id) filter (where r.status = 'present') as present_weeks,
  count(r.id) filter (where r.status = 'absent') as absent_weeks,
  count(r.id) filter (where r.status = 'excused') as excused_weeks,
  coalesce(
    round(
      (count(r.id) filter (where r.status = 'present')::numeric / nullif(count(r.id), 0)) * 100,
      2
    ),
    0
  ) as attendance_percentage
from public.members m
left join public.attendance_records r on r.member_id = m.id
left join public.attendance_sessions s on s.id = r.session_id
where m.is_active
group by m.id, m.full_name, m.church_id, m.scope, m.sunday_school_class_id, m.meeting_id;

-- ---------- 6. Harden profiles RLS + admin RPCs ----------
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_admin_update" on public.profiles
for update to authenticated
using (public.is_church_admin(church_id))
with check (public.is_church_admin(church_id));

create or replace function public.admin_update_profile_role(
  target_user_id uuid,
  new_role public.app_role
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
begin
  select church_id into target_church_id
  from public.profiles
  where id = target_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;

  if not public.is_church_admin(target_church_id) then
    raise exception 'غير مصرح بتعديل الأدوار';
  end if;

  update public.profiles
  set role = new_role
  where id = target_user_id;
end;
$$;

create or replace function public.admin_update_profile_status(
  target_user_id uuid,
  new_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
begin
  select church_id into target_church_id
  from public.profiles
  where id = target_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;

  if not public.is_church_admin(target_church_id) then
    raise exception 'غير مصرح بتعديل حالة الحساب';
  end if;

  update public.profiles
  set is_active = new_is_active
  where id = target_user_id;
end;
$$;

grant execute on function public.admin_update_profile_role(uuid, public.app_role) to authenticated;
grant execute on function public.admin_update_profile_status(uuid, boolean) to authenticated;

revoke all on function public.ensure_church(text) from public, anon, authenticated;
revoke all on function public.create_signup_profile(uuid, uuid, text, public.app_role, text, text)
  from public, anon, authenticated;

-- Rate-limit invitation brute force: require non-empty code
create or replace function public.validate_invitation_code(invite_code text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  inv record;
  normalized_code text := upper(btrim(invite_code));
begin
  if normalized_code is null or length(normalized_code) < 8 then
    return jsonb_build_object('valid', false);
  end if;

  select id, church_id, role
  into inv
  from public.invitations
  where upper(btrim(code)) = normalized_code
    and is_used = false
  limit 1;

  if not found then
    return jsonb_build_object('valid', false);
  end if;

  return jsonb_build_object(
    'valid', true,
    'invitation_id', inv.id,
    'church_id', inv.church_id,
    'role', inv.role
  );
-- RPC to fetch all invitations received by the currently authenticated user's email
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

grant execute on function public.get_my_received_invitations() to authenticated;

-- RLS policy allowing users to read invitations sent to their email
drop policy if exists "invitations_read_own_email" on public.invitations;
create policy "invitations_read_own_email" on public.invitations
for select to authenticated using (
  lower(btrim(email)) = lower(btrim(auth.jwt() ->> 'email'))
);

-- Updated accept_invitation_assignment (removes same church check and syncs user's church_id)
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

  -- Sync user's church_id to match the invitation's church
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

  update public.invitations
  set is_used = true
  where id = invitation_id;
end;
$$;

grant execute on function public.accept_invitation_assignment(uuid, uuid) to anon, authenticated;

-- Updated accept_invitation_link (removes same church check)
create or replace function public.accept_invitation_link(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select *
  into inv
  from public.invitations
  where invite_token = btrim(p_token)
    and is_used = false
    and declined_at is null
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  -- Join/Sync profile's church to match the invitation
  update public.profiles
  set church_id = inv.church_id,
      updated_at = now()
  where id = auth.uid();

  perform public.accept_invitation_assignment(inv.id, auth.uid());

  return inv.church_id;
end;
$$;

grant execute on function public.accept_invitation_link(text) to authenticated;
