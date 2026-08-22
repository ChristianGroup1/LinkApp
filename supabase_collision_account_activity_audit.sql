-- Read-only activity audit for the account that could not be separated.
-- This query does not modify any data.

with target as (
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
  ) as accounts(user_id, church_id, email)
), activity_counts as (
  select t.email, 'meetings_created' as activity, count(m.*)::bigint as row_count
  from public.meetings m, target t
  where m.church_id = t.church_id and m.created_by = t.user_id
  group by t.email

  union all
  select t.email, 'class_assignments_for_user', count(a.*)::bigint
  from public.class_assignments a, target t
  where a.church_id = t.church_id and a.user_id = t.user_id
  group by t.email

  union all
  select t.email, 'class_assignments_created_by_user', count(a.*)::bigint
  from public.class_assignments a, target t
  where a.church_id = t.church_id and a.assigned_by = t.user_id
  group by t.email

  union all
  select t.email, 'meeting_assignments_for_user', count(a.*)::bigint
  from public.meeting_assignments a, target t
  where a.church_id = t.church_id and a.user_id = t.user_id
  group by t.email

  union all
  select t.email, 'meeting_assignments_created_by_user', count(a.*)::bigint
  from public.meeting_assignments a, target t
  where a.church_id = t.church_id and a.assigned_by = t.user_id
  group by t.email

  union all
  select t.email, 'attendance_sessions_created', count(s.*)::bigint
  from public.attendance_sessions s, target t
  where s.church_id = t.church_id and s.created_by = t.user_id
  group by t.email

  union all
  select t.email, 'attendance_records_recorded', count(r.*)::bigint
  from public.attendance_records r, target t
  where r.church_id = t.church_id and r.recorded_by = t.user_id
  group by t.email

  union all
  select t.email, 'follow_ups_assigned_to_user', count(f.*)::bigint
  from public.follow_ups f, target t
  where f.church_id = t.church_id and f.responsible_user_id = t.user_id
  group by t.email

  union all
  select t.email, 'follow_ups_created_by_user', count(f.*)::bigint
  from public.follow_ups f, target t
  where f.church_id = t.church_id and f.created_by = t.user_id
  group by t.email
)
select email, activity, row_count
from activity_counts
where row_count > 0
order by email, activity;
