-- In-app support tickets submitted by authenticated LinkApp users.
-- Safe to run more than once in the Supabase SQL editor.

create table if not exists public.support_tickets (
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

create index if not exists idx_support_tickets_status_created
  on public.support_tickets (status, created_at desc);
create index if not exists idx_support_tickets_user_created
  on public.support_tickets (user_id, created_at desc);
create index if not exists idx_support_tickets_church_created
  on public.support_tickets (church_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_support_tickets_updated_at
  on public.support_tickets;
create trigger set_support_tickets_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

alter table public.support_tickets enable row level security;
revoke all on public.support_tickets from anon, authenticated;
grant insert on public.support_tickets to authenticated;

drop policy if exists "support_tickets_insert_own" on public.support_tickets;
create policy "support_tickets_insert_own" on public.support_tickets
for insert to authenticated
with check (
  user_id = auth.uid()
  and church_id = public.current_church_id()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.is_active
  )
);

-- No authenticated SELECT policy is intentional. Tickets are read only by
-- the protected Link Control dashboard through its service-role client.
comment on table public.support_tickets is
  'Private support tickets submitted from LinkApp and reviewed in Link Control.';
