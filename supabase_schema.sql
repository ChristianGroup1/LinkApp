-- ============================================================
-- Link Church Attendance Management - Complete Supabase Setup
-- ============================================================
-- Run this ENTIRE script in your Supabase SQL Editor to set up
-- (or reset) the database from scratch.
-- ============================================================

-- ---------- CLEAN TEARDOWN ----------
drop view if exists public.member_attendance_stats cascade;
drop view if exists public.member_service_year_attendance_stats cascade;
drop function if exists public.set_updated_at cascade;
drop function if exists public.current_church_id cascade;
drop function if exists public.is_church_admin cascade;
drop function if exists public.can_access_class cascade;
drop function if exists public.can_take_class_attendance cascade;
drop function if exists public.can_access_meeting cascade;
drop function if exists public.can_take_meeting_attendance cascade;
drop function if exists public.can_access_member cascade;
drop function if exists public.can_access_session cascade;
drop function if exists public.can_take_session_attendance cascade;
drop function if exists public.delete_church_for_last_admin(uuid) cascade;

drop table if exists public.follow_ups cascade;
drop table if exists public.support_tickets cascade;
drop table if exists public.attendance_records cascade;
drop table if exists public.attendance_sessions cascade;
drop table if exists public.meeting_assignments cascade;
drop table if exists public.class_assignments cascade;
drop table if exists public.invitations cascade;
drop table if exists public.members cascade;
drop table if exists public.sunday_school_classes cascade;
drop table if exists public.meetings cascade;
drop table if exists public.profiles cascade;
drop table if exists public.churches cascade;

drop type if exists public.app_role cascade;
drop type if exists public.meeting_kind cascade;
drop type if exists public.member_scope cascade;
drop type if exists public.attendance_status cascade;
drop type if exists public.follow_up_contact_status cascade;

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
create extension if not exists "pgcrypto";

-- ============================================================
-- 2. ENUMS
-- ============================================================
create type public.app_role as enum (
  'super_admin',
  'church_admin',
  'class_leader',
  'attendance_officer'
);

create type public.meeting_kind as enum ('sunday_school', 'normal');

create type public.member_scope as enum ('sunday_school_class', 'meeting');

create type public.attendance_status as enum ('present', 'absent', 'excused');

create type public.follow_up_contact_status as enum (
  'pending', 'contacted', 'no_response', 'resolved'
);

-- ============================================================
-- 3. TABLES
-- ============================================================

-- 3.1 Churches
create table public.churches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_ar text not null,
  slug text not null unique,
  phone text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3.2 Profiles (linked to auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  church_id uuid references public.churches(id) on delete set null,
  full_name text not null,
  role public.app_role not null default 'attendance_officer',
  email text,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3.3 Meetings
create table public.meetings (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  name text not null,
  name_ar text not null,
  kind public.meeting_kind not null default 'normal',
  weekday integer not null default 7 check (weekday between 1 and 7),
  attendance_reminder_minutes integer
    check (attendance_reminder_minutes between 0 and 1439),
  description text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meetings_unique_name unique (church_id, name_ar)
);

-- 3.5 Sunday School Classes
create table public.sunday_school_classes (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  name text not null,
  name_ar text not null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sunday_school_class_unique_name unique (church_id, meeting_id, name_ar)
);

-- 3.6 Members
create table public.members (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  full_name text not null,
  code text,
  scope public.member_scope not null,
  sunday_school_class_id uuid references public.sunday_school_classes(id) on delete restrict,
  meeting_id uuid references public.meetings(id) on delete restrict,
  birth_date date,
  phone text,
  whatsapp text,
  parent_name text,
  parent_phone text,
  notes text,
  avatar_url text,
  is_active boolean not null default true,
  joined_on date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint members_unique_code unique (church_id, code),
  constraint members_scope_target_check check (
    (scope = 'sunday_school_class' and sunday_school_class_id is not null and meeting_id is null)
    or
    (scope = 'meeting' and meeting_id is not null and sunday_school_class_id is null)
  )
);

-- 3.7 Class Assignments (servant -> class)
create table public.class_assignments (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  class_id uuid not null references public.sunday_school_classes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  can_take_attendance boolean not null default true,
  can_view_reports boolean not null default true,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint class_assignments_unique unique (class_id, user_id)
);

-- 3.8 Meeting Assignments (servant -> meeting)
create table public.meeting_assignments (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  can_take_attendance boolean not null default true,
  can_view_reports boolean not null default true,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint meeting_assignments_unique unique (meeting_id, user_id)
);

-- 3.9 Attendance Sessions
create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  class_id uuid references public.sunday_school_classes(id) on delete cascade,
  session_date date not null,
  week_number integer not null,
  title text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sessions_unique_slot unique nulls not distinct (church_id, meeting_id, class_id, session_date)
);

-- 3.10 Attendance Records
create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  session_id uuid not null references public.attendance_sessions(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  status public.attendance_status not null default 'absent',
  notes text,
  recorded_by uuid references auth.users(id) on delete set null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint attendance_records_unique unique (session_id, member_id)
);

-- 3.11 Follow-ups
create table public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  session_id uuid references public.attendance_sessions(id) on delete set null,
  reason text,
  contact_status public.follow_up_contact_status not null default 'pending',
  result text,
  responsible_user_id uuid references public.profiles(id) on delete set null,
  follow_up_date date not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3.12 Invitations
create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  church_id uuid not null references public.churches(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  role public.app_role not null default 'attendance_officer',
  target_id uuid,
  assignment_scope text,
  can_take_attendance boolean not null default true,
  can_view_reports boolean not null default true,
  code text not null unique,
  invite_token text not null unique,
  is_used boolean not null default false,
  declined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3.13 Support tickets
create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  church_id uuid references public.churches(id) on delete set null,
  reporter_name text not null,
  contact_email text,
  category text not null check (
    category in ('login', 'attendance', 'members', 'invitations', 'notifications', 'other')
  ),
  subject text not null check (char_length(btrim(subject)) between 3 and 120),
  description text not null check (char_length(btrim(description)) between 10 and 4000),
  status text not null default 'open' check (
    status in ('open', 'in_progress', 'resolved', 'closed')
  ),
  admin_note text,
  platform text not null,
  app_version text,
  build_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- 4. TRIGGERS (auto-update updated_at)
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_churches_updated_at before update on public.churches for each row execute function public.set_updated_at();
create trigger set_profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger set_meetings_updated_at before update on public.meetings for each row execute function public.set_updated_at();
create trigger set_sunday_school_classes_updated_at before update on public.sunday_school_classes for each row execute function public.set_updated_at();
create trigger set_members_updated_at before update on public.members for each row execute function public.set_updated_at();
create trigger set_attendance_sessions_updated_at before update on public.attendance_sessions for each row execute function public.set_updated_at();
create trigger set_attendance_records_updated_at before update on public.attendance_records for each row execute function public.set_updated_at();
create trigger set_follow_ups_updated_at before update on public.follow_ups for each row execute function public.set_updated_at();
create trigger set_invitations_updated_at before update on public.invitations for each row execute function public.set_updated_at();
create trigger set_support_tickets_updated_at before update on public.support_tickets for each row execute function public.set_updated_at();

-- ============================================================
-- 5. INDEXES
-- ============================================================
create index if not exists idx_profiles_church on public.profiles(church_id) where is_active;
create index if not exists idx_meetings_church on public.meetings(church_id) where is_active;
create index if not exists idx_classes_meeting on public.sunday_school_classes(meeting_id) where is_active;
create index if not exists idx_members_church_scope_class on public.members(church_id, scope, sunday_school_class_id) where is_active;
create index if not exists idx_members_church_scope_meeting on public.members(church_id, scope, meeting_id) where is_active;
create index if not exists idx_sessions_meeting_date on public.attendance_sessions(meeting_id, session_date);
create index if not exists idx_sessions_class on public.attendance_sessions(class_id) where class_id is not null;
create index if not exists idx_records_session_status on public.attendance_records(session_id, status);
create index if not exists idx_records_member on public.attendance_records(member_id, status);
create index if not exists idx_followups_member on public.follow_ups(member_id);
create index if not exists idx_followups_church_date on public.follow_ups(church_id, follow_up_date);
create index if not exists idx_support_tickets_status_created on public.support_tickets(status, created_at desc);
create index if not exists idx_support_tickets_user_created on public.support_tickets(user_id, created_at desc);
create index if not exists idx_support_tickets_church_created on public.support_tickets(church_id, created_at desc);

-- ============================================================
-- 6. SECURITY FUNCTIONS (RLS helpers)
-- ============================================================

create or replace function public.current_church_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select church_id
  from public.profiles
  where id = auth.uid()
    and is_active;
$$;

create or replace function public.is_church_admin(target_church_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active
      and p.church_id = target_church_id
      and p.role in ('super_admin', 'church_admin')
  );
$$;

create or replace function public.delete_church_for_last_admin(
  p_requester_id uuid
)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  target_church_id uuid;
  church_user_ids uuid[];
begin
  select p.church_id
  into target_church_id
  from public.profiles p
  where p.id = p_requester_id
    and p.is_active
    and p.role in ('church_admin', 'super_admin');

  if target_church_id is null then
    raise exception 'requester_is_not_active_admin';
  end if;

  perform 1 from public.churches
  where id = target_church_id
  for update;
  perform 1 from public.profiles
  where church_id = target_church_id
  for update;

  if exists (
    select 1 from public.profiles p
    where p.church_id = target_church_id
      and p.id <> p_requester_id
      and p.is_active
      and p.role in ('church_admin', 'super_admin')
  ) then
    raise exception 'another_active_admin_exists';
  end if;

  select coalesce(array_agg(p.id order by p.id), array[]::uuid[])
  into church_user_ids
  from public.profiles p
  where p.church_id = target_church_id;

  delete from public.attendance_records where church_id = target_church_id;
  delete from public.follow_ups where church_id = target_church_id;
  delete from public.attendance_sessions where church_id = target_church_id;
  delete from public.members where church_id = target_church_id;
  delete from public.class_assignments where church_id = target_church_id;
  delete from public.meeting_assignments where church_id = target_church_id;
  delete from public.invitations where church_id = target_church_id;
  delete from public.sunday_school_classes where church_id = target_church_id;
  delete from public.meetings where church_id = target_church_id;
  delete from public.support_tickets where church_id = target_church_id;

  if to_regclass('public.app_usage_events') is not null then
    execute 'delete from public.app_usage_events where church_id = $1'
      using target_church_id;
  end if;
  if to_regclass('public.admin_audit_logs') is not null then
    execute 'delete from public.admin_audit_logs where admin_user_id = any($1)'
      using church_user_ids;
  end if;

  delete from public.profiles where church_id = target_church_id;
  delete from public.churches where id = target_church_id;
  return church_user_ids;
end;
$$;

revoke all on function public.delete_church_for_last_admin(uuid)
from public, anon, authenticated;
grant execute on function public.delete_church_for_last_admin(uuid)
to service_role;

create or replace function public.ensure_church(church_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_name text := nullif(btrim(church_name), '');
  target_church_id uuid;
begin
  if normalized_name is null then
    raise exception 'اسم الكنيسة مطلوب';
  end if;

  -- Display names are not tenant identifiers. Always create a fresh church.
  insert into public.churches (name, name_ar, slug)
  values (
    normalized_name,
    normalized_name,
    'church-' || replace(gen_random_uuid()::text, '-', '')
  )
  returning id into target_church_id;

  return target_church_id;
end;
$$;

create or replace function public.create_signup_profile(
  profile_id uuid,
  profile_church_id uuid,
  profile_full_name text,
  profile_role public.app_role,
  profile_email text,
  profile_phone text default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_name text := nullif(btrim(profile_full_name), '');
  normalized_email text := nullif(btrim(profile_email), '');
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if not exists (select 1 from auth.users where id = profile_id) then
    raise exception 'حساب المستخدم غير موجود';
  end if;

  if not exists (select 1 from public.churches where id = profile_church_id) then
    raise exception 'الكنيسة غير موجودة';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  insert into public.profiles (
    id,
    church_id,
    full_name,
    role,
    email,
    phone
  )
  values (
    profile_id,
    profile_church_id,
    normalized_name,
    profile_role,
    normalized_email,
    nullif(btrim(profile_phone), '')
  );
end;
$$;

create or replace function public.can_access_class(target_class_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.sunday_school_classes c
    where c.id = target_class_id
      and c.church_id = public.current_church_id()
      and (
        public.is_church_admin(c.church_id)
        or exists (
          select 1
          from public.class_assignments ca
          where ca.class_id = c.id
            and ca.user_id = auth.uid()
        )
      )
  );
$$;

create or replace function public.can_take_class_attendance(target_class_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.sunday_school_classes c
    where c.id = target_class_id
      and c.church_id = public.current_church_id()
      and (
        public.is_church_admin(c.church_id)
        or exists (
          select 1
          from public.class_assignments ca
          where ca.class_id = c.id
            and ca.user_id = auth.uid()
            and ca.can_take_attendance
        )
      )
  );
$$;

create or replace function public.can_access_meeting(target_meeting_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = target_meeting_id
      and m.church_id = public.current_church_id()
      and (
        public.is_church_admin(m.church_id)
        or exists (
          select 1
          from public.meeting_assignments ma
          where ma.meeting_id = m.id
            and ma.user_id = auth.uid()
        )
        or exists (
          select 1
          from public.sunday_school_classes c
          join public.class_assignments ca on ca.class_id = c.id
          where c.meeting_id = m.id
            and ca.user_id = auth.uid()
        )
      )
  );
$$;

create or replace function public.can_take_meeting_attendance(target_meeting_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.meetings m
    where m.id = target_meeting_id
      and m.church_id = public.current_church_id()
      and (
        public.is_church_admin(m.church_id)
        or exists (
          select 1
          from public.meeting_assignments ma
          where ma.meeting_id = m.id
            and ma.user_id = auth.uid()
            and ma.can_take_attendance
        )
      )
  );
$$;

create or replace function public.can_access_member(target_member_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.members m
    where m.id = target_member_id
      and m.church_id = public.current_church_id()
      and (
        public.is_church_admin(m.church_id)
        or (m.sunday_school_class_id is not null and public.can_access_class(m.sunday_school_class_id))
        or (m.meeting_id is not null and public.can_access_meeting(m.meeting_id))
      )
  );
$$;

create or replace function public.can_access_session(target_session_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.attendance_sessions s
    where s.id = target_session_id
      and s.church_id = public.current_church_id()
      and (
        public.is_church_admin(s.church_id)
        or (s.class_id is not null and public.can_access_class(s.class_id))
        or (s.class_id is null and public.can_access_meeting(s.meeting_id))
      )
  );
$$;

create or replace function public.can_take_session_attendance(target_session_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.attendance_sessions s
    where s.id = target_session_id
      and s.church_id = public.current_church_id()
      and (
        public.is_church_admin(s.church_id)
        or (s.class_id is not null and public.can_take_class_attendance(s.class_id))
        or (s.class_id is null and public.can_take_meeting_attendance(s.meeting_id))
      )
  );
$$;

create or replace function public.create_attendance_session(
  target_meeting_id uuid,
  target_class_id uuid,
  target_session_date date,
  target_week_number integer,
  target_title text default null
)
returns public.attendance_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile public.profiles%rowtype;
  saved_session public.attendance_sessions%rowtype;
begin
  select *
    into current_profile
    from public.profiles
    where id = auth.uid()
      and is_active;

  if current_profile.id is null then
    raise exception 'المستخدم الحالي غير مسجل أو غير مفعل';
  end if;

  if not exists (
    select 1
    from public.meetings m
    where m.id = target_meeting_id
      and m.church_id = current_profile.church_id
      and m.is_active
  ) then
    raise exception 'الاجتماع غير تابع لكنيستك أو غير مفعل';
  end if;

  if target_class_id is not null and not exists (
    select 1
    from public.sunday_school_classes c
    where c.id = target_class_id
      and c.meeting_id = target_meeting_id
      and c.church_id = current_profile.church_id
      and c.is_active
  ) then
    raise exception 'الفصل غير تابع لهذا الاجتماع';
  end if;

  if not (
    current_profile.role in ('super_admin', 'church_admin')
    or (
      target_class_id is not null
      and exists (
        select 1
        from public.class_assignments ca
        where ca.class_id = target_class_id
          and ca.user_id = current_profile.id
      )
    )
    or (
      target_class_id is null
      and exists (
        select 1
        from public.meeting_assignments ma
        where ma.meeting_id = target_meeting_id
          and ma.user_id = current_profile.id
      )
    )
  ) then
    raise exception 'ليس لديك صلاحية تسجيل حضور لهذا الاجتماع';
  end if;

  insert into public.attendance_sessions (
    church_id,
    meeting_id,
    class_id,
    session_date,
    week_number,
    title,
    created_by
  )
  values (
    current_profile.church_id,
    target_meeting_id,
    target_class_id,
    target_session_date,
    target_week_number,
    nullif(btrim(target_title), ''),
    current_profile.id
  )
  on conflict (church_id, meeting_id, class_id, session_date)
  do update
    set week_number = excluded.week_number,
        title = coalesce(excluded.title, attendance_sessions.title)
  returning * into saved_session;

  return saved_session;
end;
$$;

-- ============================================================
-- 7. GRANT EXECUTE
-- ============================================================
grant execute on function public.current_church_id() to authenticated;
grant execute on function public.is_church_admin(uuid) to authenticated;
grant execute on function public.admin_update_profile_role(uuid, public.app_role) to authenticated;
grant execute on function public.admin_update_profile_status(uuid, boolean) to authenticated;
grant execute on function public.can_access_class(uuid) to authenticated;
grant execute on function public.can_take_class_attendance(uuid) to authenticated;
grant execute on function public.can_access_meeting(uuid) to authenticated;
grant execute on function public.can_take_meeting_attendance(uuid) to authenticated;
grant execute on function public.can_access_member(uuid) to authenticated;
grant execute on function public.can_access_session(uuid) to authenticated;
grant execute on function public.can_take_session_attendance(uuid) to authenticated;
grant execute on function public.create_attendance_session(uuid, uuid, date, integer, text) to authenticated;

-- ============================================================
-- 8. ROW LEVEL SECURITY
-- ============================================================


alter table public.profiles enable row level security;
alter table public.meetings enable row level security;
alter table public.sunday_school_classes enable row level security;
alter table public.members enable row level security;
alter table public.class_assignments enable row level security;
alter table public.meeting_assignments enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.follow_ups enable row level security;
alter table public.invitations enable row level security;
alter table public.support_tickets enable row level security;

-- 8.1 Churches
alter table public.churches enable row level security;

create policy "churches_select_same_church" on public.churches
for select to authenticated
using (id = public.current_church_id());

create policy "churches_admin_update" on public.churches
for update to authenticated
using (public.is_church_admin(id))
with check (public.is_church_admin(id));

-- 8.2 Profiles
create policy "profiles_select_same_church" on public.profiles
for select using (
  id = auth.uid()
  or church_id = public.current_church_id()
);
create policy "profiles_admin_update" on public.profiles
for update to authenticated
using (public.is_church_admin(church_id))
with check (public.is_church_admin(church_id));

-- 8.3 Meetings
create policy "meetings_select" on public.meetings
for select using (church_id = public.current_church_id());
create policy "meetings_admin_manage" on public.meetings
for all using (public.is_church_admin(church_id)) with check (public.is_church_admin(church_id));

-- 8.5 Sunday School Classes
create policy "classes_select" on public.sunday_school_classes
for select using (church_id = public.current_church_id());
create policy "classes_admin_manage" on public.sunday_school_classes
for all using (public.is_church_admin(church_id)) with check (public.is_church_admin(church_id));

-- 8.6 Members (admins + servants with attendance permissions)
create policy "members_select_access" on public.members
for select to authenticated using (
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
create policy "members_manage" on public.members
for all using (
  public.is_church_admin(church_id)
  or (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.church_id = members.church_id
        and p.is_active
    )
    and (
      (members.sunday_school_class_id is not null and public.can_take_class_attendance(members.sunday_school_class_id))
      or
      (members.meeting_id is not null and public.can_take_meeting_attendance(members.meeting_id))
    )
  )
) with check (
  public.is_church_admin(church_id)
  or (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.church_id = members.church_id
        and p.is_active
    )
    and (
      (members.sunday_school_class_id is not null and public.can_take_class_attendance(members.sunday_school_class_id))
      or
      (members.meeting_id is not null and public.can_take_meeting_attendance(members.meeting_id))
    )
  )
);

-- 8.7 Class Assignments
create policy "class_assignments_select" on public.class_assignments
for select using (church_id = public.current_church_id());
create policy "class_assignments_admin_manage" on public.class_assignments
for all using (public.is_church_admin(church_id)) with check (public.is_church_admin(church_id));

-- 8.8 Meeting Assignments
create policy "meeting_assignments_select" on public.meeting_assignments
for select using (church_id = public.current_church_id());
create policy "meeting_assignments_admin_manage" on public.meeting_assignments
for all using (public.is_church_admin(church_id)) with check (public.is_church_admin(church_id));

-- 8.9 Attendance Sessions
create policy "sessions_select_access" on public.attendance_sessions
for select using (public.can_access_session(id));
create policy "sessions_insert_take_attendance" on public.attendance_sessions
for insert with check (
  church_id = public.current_church_id()
  and (
    public.is_church_admin(church_id)
    or (class_id is not null and public.can_take_class_attendance(class_id))
    or (class_id is null and public.can_take_meeting_attendance(meeting_id))
  )
);
create policy "sessions_update_take_attendance" on public.attendance_sessions
for update using (public.can_take_session_attendance(id))
with check (public.can_take_session_attendance(id));
create policy "sessions_delete_take_attendance" on public.attendance_sessions
for delete using (
  public.is_church_admin(church_id)
  or public.can_take_session_attendance(id)
);

-- 8.10 Attendance Records
create policy "records_select_access" on public.attendance_records
for select using (public.can_access_session(session_id));
create policy "records_manage_take_attendance" on public.attendance_records
for all using (public.can_take_session_attendance(session_id))
with check (
  church_id = public.current_church_id()
  and public.can_take_session_attendance(session_id)
);

-- 8.11 Follow-ups
create policy "followups_select_access" on public.follow_ups
for select using (public.can_access_member(member_id));
create policy "followups_insert_access" on public.follow_ups
for insert with check (
  church_id = public.current_church_id()
  and public.can_access_member(member_id)
);
create policy "followups_update_responsible_or_admin" on public.follow_ups
for update using (
  public.is_church_admin(church_id)
  or responsible_user_id = auth.uid()
)
with check (
  public.is_church_admin(church_id)
  or responsible_user_id = auth.uid()
);
create policy "followups_delete_admin" on public.follow_ups
for delete using (public.is_church_admin(church_id));

-- 8.12 Invitations
create policy "invitations_admin_manage" on public.invitations
for all to authenticated using (
  exists (
    select 1 from public.profiles
    where profiles.id = auth.uid()
    and profiles.church_id = invitations.church_id
    and (profiles.role = 'super_admin' or profiles.role = 'church_admin')
  )
);

-- 8.13 Support tickets: users may submit, but only Link Control can read.
revoke all on public.support_tickets from anon, authenticated;
grant insert on public.support_tickets to authenticated;
create policy "support_tickets_insert_own" on public.support_tickets
for insert to authenticated
with check (
  user_id = auth.uid()
  and church_id = public.current_church_id()
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active
  )
);

create or replace function public.validate_invitation_code(invite_code text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  inv record;
  normalized text := upper(btrim(invite_code));
begin
  if length(normalized) < 8 then
    return jsonb_build_object('valid', false);
  end if;

  select id, church_id, role
  into inv
  from public.invitations
  where upper(btrim(code)) = normalized
    and is_used = false
    and declined_at is null
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

create or replace function public.get_invitation_by_token(p_token text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  inv record;
begin
  if nullif(btrim(p_token), '') is null then
    return jsonb_build_object('valid', false);
  end if;

  select i.*, c.name_ar as church_name_ar
  into inv
  from public.invitations i
  join public.churches c on c.id = i.church_id
  where i.invite_token = btrim(p_token)
  limit 1;

  if not found then
    return jsonb_build_object('valid', false);
  end if;

  if inv.is_used then
    return jsonb_build_object('valid', false, 'status', 'used');
  end if;

  if inv.declined_at is not null then
    return jsonb_build_object('valid', false, 'status', 'declined');
  end if;

  return jsonb_build_object(
    'valid', true,
    'status', 'pending',
    'invitation_id', inv.id,
    'church_id', inv.church_id,
    'church_name', inv.church_name_ar,
    'invitee_name', inv.full_name,
    'email', inv.email,
    'role', inv.role,
    'assignment_scope', inv.assignment_scope,
    'can_take_attendance', coalesce(inv.can_take_attendance, true),
    'can_view_reports', coalesce(inv.can_view_reports, true)
  );
end;
$$;

grant execute on function public.get_invitation_by_token(text) to anon, authenticated;

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

  select lower(btrim(email)) into current_email
  from auth.users where id = auth.uid();

  if nullif(lower(btrim(inv.email)), '') is null
     or current_email is distinct from lower(btrim(inv.email)) then
    raise exception 'هذه الدعوة موجهة إلى بريد إلكتروني مختلف. سجّل الدخول بالبريد المدعو.';
  end if;

  update public.invitations
  set declined_at = now()
  where id = inv.id;
end;
$$;

revoke all on function public.decline_invitation_by_token(text) from public, anon;
grant execute on function public.decline_invitation_by_token(text) to authenticated;

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

  select lower(btrim(email)) into current_email
  from auth.users where id = auth.uid();

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

revoke all on function public.accept_invitation_link(text) from public, anon;
grant execute on function public.accept_invitation_link(text) to authenticated;

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

  select *
  into inv
  from public.invitations
  where is_used = false
    and declined_at is null
    and (
      (normalized_token is not null and invite_token = normalized_token)
      or (normalized_code is not null and upper(btrim(code)) = normalized_code)
    )
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو تم استخدامها أو رفضها.';
  end if;

  if normalized_token is not null then
    select lower(btrim(email)) into current_email
    from auth.users where id = auth.uid();

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
  target_profile public.profiles%rowtype;
begin
  select * into target_profile
  from public.profiles
  where id = target_user_id;

  if not found then
    raise exception 'المستخدم غير موجود';
  end if;

  if not public.is_church_admin(target_profile.church_id) then
    raise exception 'غير مصرح بتعديل حالة الحساب';
  end if;

  if target_user_id = auth.uid() and not new_is_active then
    raise exception 'لا يمكنك إيقاف حسابك الحالي';
  end if;

  if target_profile.role = 'super_admin' and not new_is_active then
    raise exception 'لا يمكن إيقاف حساب المدير الرئيسي';
  end if;

  update public.profiles
  set is_active = new_is_active
  where id = target_user_id;
end;
$$;

revoke all on function public.register_new_church_signup(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.register_new_church_signup(uuid, text, text, text, text)
  to authenticated;

revoke all on function public.register_invited_signup(uuid, text, text, text, text, text)
  from public, anon;
grant execute on function public.register_invited_signup(uuid, text, text, text, text, text)
  to authenticated;
grant execute on function public.admin_update_profile_role(uuid, public.app_role) to authenticated;
grant execute on function public.admin_update_profile_status(uuid, boolean) to authenticated;

revoke all on function public.ensure_church(text) from public, anon, authenticated;
revoke all on function public.create_signup_profile(uuid, uuid, text, public.app_role, text, text)
  from public, anon, authenticated;

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
    and is_used = false
    and declined_at is null;

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

revoke all on function public.accept_invitation_assignment(uuid, uuid)
  from public, anon, authenticated;

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

-- ============================================================
-- 9. REPORTS VIEW
-- ============================================================
create or replace view public.member_attendance_stats
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

-- ============================================================
-- 10. REALTIME
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'attendance_records'
  ) then
    alter publication supabase_realtime add table public.attendance_records;
  end if;
end $$;
