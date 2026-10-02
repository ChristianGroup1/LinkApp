-- Keep pastoral visits in the existing church-scoped, offline-capable follow-up
-- workflow while separating them from absence follow-up reports.
alter table public.follow_ups
  add column if not exists activity_type text not null default 'absence_follow_up';

alter table public.follow_ups
  drop constraint if exists follow_ups_activity_type_check;

alter table public.follow_ups
  add constraint follow_ups_activity_type_check
  check (activity_type in ('absence_follow_up', 'visit'));

create index if not exists idx_follow_ups_church_activity_date
  on public.follow_ups (church_id, activity_type, follow_up_date desc);
