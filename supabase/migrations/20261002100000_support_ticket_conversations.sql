create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check (sender_role in ('reporter', 'support')),
  message text not null check (length(trim(message)) between 1 and 5000),
  created_at timestamptz not null default now()
);

create index if not exists support_ticket_messages_ticket_created_idx
  on public.support_ticket_messages (ticket_id, created_at);

alter table public.support_ticket_messages enable row level security;

grant select, insert on public.support_ticket_messages to authenticated;
grant all on public.support_ticket_messages to service_role;

drop policy if exists support_ticket_messages_select_own
  on public.support_ticket_messages;
create policy support_ticket_messages_select_own
  on public.support_ticket_messages
  for select to authenticated
  using (
    exists (
      select 1
      from public.support_tickets ticket
      where ticket.id = ticket_id
        and ticket.user_id = auth.uid()
    )
  );

drop policy if exists support_ticket_messages_insert_own
  on public.support_ticket_messages;
create policy support_ticket_messages_insert_own
  on public.support_ticket_messages
  for insert to authenticated
  with check (
    sender_role = 'reporter'
    and sender_id = auth.uid()
    and exists (
      select 1
      from public.support_tickets ticket
      where ticket.id = ticket_id
        and ticket.user_id = auth.uid()
    )
  );
