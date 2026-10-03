-- Seed 1,000 demo members for performance testing.
-- Replace the three UUIDs below with ids from your church before running.
--
-- Example discovery:
--   select id, name_ar from public.churches;
--   select id, name_ar from public.meetings where church_id = '<church_id>';
--   select id, name_ar from public.sunday_school_classes where church_id = '<church_id>';
--
-- Safe to re-run: deletes previous rows that use the LN-SEED-***** code prefix.

do $$
declare
  target_church_id uuid := '00000000-0000-0000-0000-000000000000'; -- TODO
  target_meeting_id uuid := '00000000-0000-0000-0000-000000000000'; -- TODO
  target_class_id uuid := '00000000-0000-0000-0000-000000000000'; -- TODO
  i integer;
  member_id uuid;
begin
  if target_church_id = '00000000-0000-0000-0000-000000000000' then
    raise exception 'Set target_church_id / meeting / class before seeding';
  end if;

  delete from public.members
  where church_id = target_church_id
    and code like 'LN-SEED-%';

  for i in 1..1000 loop
    member_id := gen_random_uuid();
    if (i % 2) = 0 then
      insert into public.members (
        id,
        church_id,
        full_name,
        scope,
        sunday_school_class_id,
        meeting_id,
        code,
        phone,
        birth_date,
        is_active,
        joined_on
      ) values (
        member_id,
        target_church_id,
        format('مخدوم تجريبي %s', lpad(i::text, 4, '0')),
        'sunday_school_class',
        target_class_id,
        null,
        format('LN-SEED-%s', lpad(i::text, 5, '0')),
        format('010%s', lpad(i::text, 8, '0')),
        make_date(2000 + (i % 20), ((i - 1) % 12) + 1, ((i - 1) % 28) + 1),
        true,
        current_date
      );
    else
      insert into public.members (
        id,
        church_id,
        full_name,
        scope,
        sunday_school_class_id,
        meeting_id,
        code,
        phone,
        birth_date,
        is_active,
        joined_on
      ) values (
        member_id,
        target_church_id,
        format('مخدوم تجريبي %s', lpad(i::text, 4, '0')),
        'meeting',
        null,
        target_meeting_id,
        format('LN-SEED-%s', lpad(i::text, 5, '0')),
        format('010%s', lpad(i::text, 8, '0')),
        make_date(2000 + (i % 20), ((i - 1) % 12) + 1, ((i - 1) % 28) + 1),
        true,
        current_date
      );

      insert into public.member_meeting_assignments (
        church_id,
        member_id,
        meeting_id,
        sunday_school_class_id,
        is_primary
      ) values (
        target_church_id,
        member_id,
        target_meeting_id,
        null,
        true
      )
      on conflict (member_id, meeting_id) do nothing;
    end if;
  end loop;
end $$;

-- Quick checks after seeding:
-- select count(*) from public.members where code like 'LN-SEED-%';
-- select scope, count(*) from public.members where code like 'LN-SEED-%' group by 1;
