alter table public.invitations
  add column if not exists assignment_scope text,
  add column if not exists can_take_attendance boolean not null default true,
  add column if not exists can_view_reports boolean not null default true;
