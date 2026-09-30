-- Let authenticated users review only the support tickets they submitted.
-- Link Control continues to access all tickets through its service-role client.
grant select on public.support_tickets to authenticated;

drop policy if exists "support_tickets_select_own" on public.support_tickets;
create policy "support_tickets_select_own" on public.support_tickets
for select to authenticated
using (user_id = auth.uid());
