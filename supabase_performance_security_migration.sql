-- Performance & security hardening driven by Supabase advisors.
--
-- 1) Covering indexes for all foreign keys flagged as unindexed.
-- 2) RLS initplan fixes: wrap auth.uid()/auth.jwt()/current_church_id() in
--    scalar subqueries so they evaluate once per statement, not per row.
-- 3) Split FOR ALL policies that overlapped dedicated SELECT policies, so
--    each role+action pair evaluates a single policy. SELECT coverage is
--    preserved: every writer condition is a subset of the matching
--    can_access_* read condition (verified against the function sources),
--    except invitations where the admin read branch is merged explicitly.
-- 4) Revoke anon EXECUTE on SECURITY DEFINER helpers. Only
--    validate_invitation_code and get_invitation_by_token stay callable by
--    anon because the app uses them before login (invitation preview and
--    activation-code validation). register_* run after a session exists.
-- 5) Pin search_path of set_updated_at; document admin_audit_logs RLS.
--
-- NOTE: enable "Leaked password protection" manually in
-- Dashboard -> Authentication -> Providers -> Email (no SQL equivalent).

-- ---------------------------------------------------------------------------
-- 1) Foreign-key covering indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_attendance_records_church_id
  on public.attendance_records (church_id);
create index if not exists idx_attendance_records_recorded_by
  on public.attendance_records (recorded_by);
create index if not exists idx_attendance_sessions_created_by
  on public.attendance_sessions (created_by);
create index if not exists idx_class_assignments_assigned_by
  on public.class_assignments (assigned_by);
create index if not exists idx_class_assignments_church_id
  on public.class_assignments (church_id);
create index if not exists idx_class_assignments_user_id
  on public.class_assignments (user_id);
create index if not exists idx_follow_ups_created_by
  on public.follow_ups (created_by);
create index if not exists idx_follow_ups_responsible_user_id
  on public.follow_ups (responsible_user_id);
create index if not exists idx_follow_ups_session_id
  on public.follow_ups (session_id);
create index if not exists idx_meeting_assignments_assigned_by
  on public.meeting_assignments (assigned_by);
create index if not exists idx_meeting_assignments_church_id
  on public.meeting_assignments (church_id);
create index if not exists idx_meeting_assignments_user_id
  on public.meeting_assignments (user_id);
create index if not exists idx_meetings_created_by
  on public.meetings (created_by);
create index if not exists idx_members_meeting_id
  on public.members (meeting_id);
create index if not exists idx_members_sunday_school_class_id
  on public.members (sunday_school_class_id);

-- ---------------------------------------------------------------------------
-- 2) RLS initplan fixes on kept policies
-- ---------------------------------------------------------------------------
alter policy profiles_select_same_church on public.profiles
  using (
    (id = (select auth.uid()))
    or (church_id = (select public.current_church_id()))
  );

alter policy followups_update_responsible_or_admin on public.follow_ups
  using (
    public.is_church_admin(church_id)
    or (responsible_user_id = (select auth.uid()))
  )
  with check (
    public.is_church_admin(church_id)
    or (responsible_user_id = (select auth.uid()))
  );

alter policy usage_events_insert_own on public.app_usage_events
  with check (
    (user_id = (select auth.uid()))
    and (church_id = (select public.current_church_id()))
  );

alter policy support_tickets_insert_own on public.support_tickets
  with check (
    (user_id = (select auth.uid()))
    and (church_id = (select public.current_church_id()))
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.is_active
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Split overlapping FOR ALL policies into INSERT/UPDATE/DELETE
-- ---------------------------------------------------------------------------

-- members ------------------------------------------------------------------
drop policy if exists members_manage on public.members;
drop policy if exists members_insert on public.members;
create policy members_insert on public.members
  for insert to authenticated
  with check (
    public.is_church_admin(church_id)
    or (
      exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.church_id = members.church_id
          and p.is_active
      )
      and (
        ((sunday_school_class_id is not null)
          and public.can_take_class_attendance(sunday_school_class_id))
        or ((meeting_id is not null)
          and public.can_take_meeting_attendance(meeting_id))
      )
    )
  );
drop policy if exists members_update on public.members;
create policy members_update on public.members
  for update to authenticated
  using (
    public.is_church_admin(church_id)
    or (
      exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.church_id = members.church_id
          and p.is_active
      )
      and (
        ((sunday_school_class_id is not null)
          and public.can_take_class_attendance(sunday_school_class_id))
        or ((meeting_id is not null)
          and public.can_take_meeting_attendance(meeting_id))
      )
    )
  )
  with check (
    public.is_church_admin(church_id)
    or (
      exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.church_id = members.church_id
          and p.is_active
      )
      and (
        ((sunday_school_class_id is not null)
          and public.can_take_class_attendance(sunday_school_class_id))
        or ((meeting_id is not null)
          and public.can_take_meeting_attendance(meeting_id))
      )
    )
  );
drop policy if exists members_delete on public.members;
create policy members_delete on public.members
  for delete to authenticated
  using (
    public.is_church_admin(church_id)
    or (
      exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and p.church_id = members.church_id
          and p.is_active
      )
      and (
        ((sunday_school_class_id is not null)
          and public.can_take_class_attendance(sunday_school_class_id))
        or ((meeting_id is not null)
          and public.can_take_meeting_attendance(meeting_id))
      )
    )
  );
alter policy members_select_access on public.members to authenticated;

-- meetings -----------------------------------------------------------------
drop policy if exists meetings_admin_manage on public.meetings;
drop policy if exists meetings_admin_insert on public.meetings;
create policy meetings_admin_insert on public.meetings
  for insert to authenticated
  with check (public.is_church_admin(church_id));
drop policy if exists meetings_admin_update on public.meetings;
create policy meetings_admin_update on public.meetings
  for update to authenticated
  using (public.is_church_admin(church_id))
  with check (public.is_church_admin(church_id));
drop policy if exists meetings_admin_delete on public.meetings;
create policy meetings_admin_delete on public.meetings
  for delete to authenticated
  using (public.is_church_admin(church_id));
alter policy meetings_select on public.meetings to authenticated;

-- sunday_school_classes ------------------------------------------------------
drop policy if exists classes_admin_manage on public.sunday_school_classes;
drop policy if exists classes_admin_insert on public.sunday_school_classes;
create policy classes_admin_insert on public.sunday_school_classes
  for insert to authenticated
  with check (public.is_church_admin(church_id));
drop policy if exists classes_admin_update on public.sunday_school_classes;
create policy classes_admin_update on public.sunday_school_classes
  for update to authenticated
  using (public.is_church_admin(church_id))
  with check (public.is_church_admin(church_id));
drop policy if exists classes_admin_delete on public.sunday_school_classes;
create policy classes_admin_delete on public.sunday_school_classes
  for delete to authenticated
  using (public.is_church_admin(church_id));
alter policy classes_select on public.sunday_school_classes to authenticated;

-- class_assignments ----------------------------------------------------------
drop policy if exists class_assignments_admin_manage on public.class_assignments;
drop policy if exists class_assignments_admin_insert on public.class_assignments;
create policy class_assignments_admin_insert on public.class_assignments
  for insert to authenticated
  with check (public.is_church_admin(church_id));
drop policy if exists class_assignments_admin_update on public.class_assignments;
create policy class_assignments_admin_update on public.class_assignments
  for update to authenticated
  using (public.is_church_admin(church_id))
  with check (public.is_church_admin(church_id));
drop policy if exists class_assignments_admin_delete on public.class_assignments;
create policy class_assignments_admin_delete on public.class_assignments
  for delete to authenticated
  using (public.is_church_admin(church_id));
alter policy class_assignments_select on public.class_assignments
  to authenticated;

-- meeting_assignments --------------------------------------------------------
drop policy if exists meeting_assignments_admin_manage on public.meeting_assignments;
drop policy if exists meeting_assignments_admin_insert on public.meeting_assignments;
create policy meeting_assignments_admin_insert on public.meeting_assignments
  for insert to authenticated
  with check (public.is_church_admin(church_id));
drop policy if exists meeting_assignments_admin_update on public.meeting_assignments;
create policy meeting_assignments_admin_update on public.meeting_assignments
  for update to authenticated
  using (public.is_church_admin(church_id))
  with check (public.is_church_admin(church_id));
drop policy if exists meeting_assignments_admin_delete on public.meeting_assignments;
create policy meeting_assignments_admin_delete on public.meeting_assignments
  for delete to authenticated
  using (public.is_church_admin(church_id));
alter policy meeting_assignments_select on public.meeting_assignments
  to authenticated;

-- attendance_records ---------------------------------------------------------
drop policy if exists records_manage_take_attendance on public.attendance_records;
drop policy if exists records_insert_take_attendance on public.attendance_records;
create policy records_insert_take_attendance on public.attendance_records
  for insert to authenticated
  with check (
    (church_id = (select public.current_church_id()))
    and public.can_take_session_attendance(session_id)
  );
drop policy if exists records_update_take_attendance on public.attendance_records;
create policy records_update_take_attendance on public.attendance_records
  for update to authenticated
  using (public.can_take_session_attendance(session_id))
  with check (
    (church_id = (select public.current_church_id()))
    and public.can_take_session_attendance(session_id)
  );
drop policy if exists records_delete_take_attendance on public.attendance_records;
create policy records_delete_take_attendance on public.attendance_records
  for delete to authenticated
  using (public.can_take_session_attendance(session_id));
alter policy records_select_access on public.attendance_records
  to authenticated;

-- invitations ----------------------------------------------------------------
-- Admin reads were only granted through the FOR ALL policy, so the merged
-- SELECT policy keeps both branches: own email OR church admin.
drop policy if exists invitations_admin_manage on public.invitations;
drop policy if exists invitations_read_own_email on public.invitations;
drop policy if exists invitations_select on public.invitations;
create policy invitations_select on public.invitations
  for select to authenticated
  using (
    (lower(btrim(email)) = lower(btrim(((select auth.jwt()) ->> 'email'))))
    or exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.church_id = invitations.church_id
        and profiles.role in
          ('super_admin'::public.app_role, 'church_admin'::public.app_role)
    )
  );
drop policy if exists invitations_admin_insert on public.invitations;
create policy invitations_admin_insert on public.invitations
  for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.church_id = invitations.church_id
        and profiles.role in
          ('super_admin'::public.app_role, 'church_admin'::public.app_role)
    )
  );
drop policy if exists invitations_admin_update on public.invitations;
create policy invitations_admin_update on public.invitations
  for update to authenticated
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.church_id = invitations.church_id
        and profiles.role in
          ('super_admin'::public.app_role, 'church_admin'::public.app_role)
    )
  )
  with check (
    exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.church_id = invitations.church_id
        and profiles.role in
          ('super_admin'::public.app_role, 'church_admin'::public.app_role)
    )
  );
drop policy if exists invitations_admin_delete on public.invitations;
create policy invitations_admin_delete on public.invitations
  for delete to authenticated
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.church_id = invitations.church_id
        and profiles.role in
          ('super_admin'::public.app_role, 'church_admin'::public.app_role)
    )
  );

-- ---------------------------------------------------------------------------
-- 4) Function EXECUTE privileges
-- ---------------------------------------------------------------------------
do $$
declare fn record;
begin
  -- Internal helpers and admin RPCs: authenticated app users only.
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'admin_update_profile_role',
        'admin_update_profile_status',
        'can_access_class',
        'can_access_meeting',
        'can_access_member',
        'can_access_session',
        'can_take_class_attendance',
        'can_take_meeting_attendance',
        'can_take_session_attendance',
        'create_attendance_session',
        'current_church_id',
        'delete_meeting_cascade',
        'delete_sunday_school_class_cascade',
        'is_admin',
        'is_church_admin',
        'register_invited_signup'
      )
  loop
    execute format('revoke execute on function %s from public, anon', fn.sig);
    execute format(
      'grant execute on function %s to authenticated, service_role',
      fn.sig
    );
  end loop;

  -- Trigger-only functions: no direct EXECUTE needed by any client role.
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'remove_class_pending_invitations',
        'remove_meeting_pending_invitations',
        'set_updated_at'
      )
  loop
    execute format(
      'revoke execute on function %s from public, anon, authenticated',
      fn.sig
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5) Misc hardening
-- ---------------------------------------------------------------------------
alter function public.set_updated_at() set search_path = pg_catalog, public;

comment on table public.admin_audit_logs is
  'Written by service-role/dashboard tooling only. RLS is enabled with no '
  'policies on purpose: client roles (anon/authenticated) must have no '
  'access to audit history.';

-- ---------------------------------------------------------------------------
-- 6) Realtime: servants see each other's attendance/member/follow-up writes
-- ---------------------------------------------------------------------------
alter table public.attendance_records replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'members'
  ) then
    alter publication supabase_realtime add table public.members;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'follow_ups'
  ) then
    alter publication supabase_realtime add table public.follow_ups;
  end if;
end $$;
