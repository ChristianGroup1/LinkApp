-- One-time repair for the two duplicate-name collisions audited on 2026-08-15.
-- The first signup in each church keeps the existing church and its data.
-- The later signup is moved to a new, empty church with the same display name.

begin;

do $$
declare
  target record;
  current_church_id uuid;
  current_email text;
  copied_name text;
  copied_name_ar text;
  new_church_id uuid;
begin
  for target in
    select *
    from (values
      (
        '599019b5-65bb-42c1-b49a-98508981ac39'::uuid,
        '45be6814-1928-479d-8243-293d69291a57'::uuid,
        'classleader@gmail.com'::text
      ),
      (
        '592065b7-21cc-4c0f-8722-42367113f84f'::uuid,
        'ceef2d15-b4a1-420d-a75e-e473f25dfc54'::uuid,
        'fadykhayrat88@gmail.com'::text
      )
    ) as accounts(user_id, expected_old_church_id, expected_email)
  loop
    select
      p.church_id,
      lower(coalesce(p.email, u.email))
    into current_church_id, current_email
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.id = target.user_id
    for update of p;

    if not found then
      raise exception 'Profile % was not found; no changes were committed',
        target.user_id;
    end if;

    if current_church_id <> target.expected_old_church_id then
      raise exception 'Profile % is no longer in expected church %; no changes were committed',
        target.user_id,
        target.expected_old_church_id;
    end if;

    if current_email is distinct from lower(target.expected_email) then
      raise exception 'Email mismatch for profile %; no changes were committed',
        target.user_id;
    end if;

    -- Do not silently strand, delete, or transfer activity created while the
    -- account was incorrectly attached to the old tenant. The whole
    -- transaction is rolled back if any such relationship exists.
    if exists (
      select 1 from public.meetings
      where church_id = target.expected_old_church_id
        and created_by = target.user_id
    ) or exists (
      select 1 from public.class_assignments
      where church_id = target.expected_old_church_id
        and (user_id = target.user_id or assigned_by = target.user_id)
    ) or exists (
      select 1 from public.meeting_assignments
      where church_id = target.expected_old_church_id
        and (user_id = target.user_id or assigned_by = target.user_id)
    ) or exists (
      select 1 from public.attendance_sessions
      where church_id = target.expected_old_church_id
        and created_by = target.user_id
    ) or exists (
      select 1 from public.attendance_records
      where church_id = target.expected_old_church_id
        and recorded_by = target.user_id
    ) or exists (
      select 1 from public.follow_ups
      where church_id = target.expected_old_church_id
        and (
          responsible_user_id = target.user_id
          or created_by = target.user_id
        )
    ) then
      raise exception 'Profile % has activity in the old church; no changes were committed',
        target.user_id;
    end if;

    select name, name_ar
    into copied_name, copied_name_ar
    from public.churches
    where id = target.expected_old_church_id;

    if not found then
      raise exception 'Church % was not found; no changes were committed',
        target.expected_old_church_id;
    end if;

    insert into public.churches (name, name_ar, slug)
    values (
      copied_name,
      copied_name_ar,
      'church-' || replace(gen_random_uuid()::text, '-', '')
    )
    returning id into new_church_id;

    update public.profiles
    set
      church_id = new_church_id,
      role = 'church_admin',
      is_active = true,
      updated_at = now()
    where id = target.user_id;
  end loop;
end;
$$;

commit;

-- Expected: four different church_id values, one for every account.
select
  p.id as user_id,
  p.church_id,
  c.name_ar as church_name,
  coalesce(p.email, u.email) as email,
  p.role,
  p.is_active
from public.profiles p
join public.churches c on c.id = p.church_id
join auth.users u on u.id = p.id
where p.id in (
  '1a06d122-4331-406c-a013-93ee5d3880f9'::uuid,
  '599019b5-65bb-42c1-b49a-98508981ac39'::uuid,
  '26fb447a-72bb-43db-b1b1-1b003c00aa7b'::uuid,
  '592065b7-21cc-4c0f-8722-42367113f84f'::uuid
)
order by p.created_at, p.id;
