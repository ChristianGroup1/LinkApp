-- Keep invited users as authenticated accounts without assigning them to a
-- church until they explicitly accept the invitation in the app.

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

  select * into inv
  from public.invitations
  where invite_token = btrim(p_token)
  for update;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;
  if inv.is_used or inv.declined_at is not null then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  select lower(btrim(email)) into current_email
  from auth.users where id = auth.uid();

  if nullif(lower(btrim(inv.email)), '') is null
     or lower(btrim(inv.email)) = 'no-email@linkapp.local' then
    if nullif(current_email, '') is null
       or current_email = 'no-email@linkapp.local' then
      raise exception 'أدخل بريدك الإلكتروني الحقيقي لإكمال الدعوة.';
    end if;
  elsif current_email is distinct from lower(btrim(inv.email)) then
    raise exception 'هذه الدعوة موجهة إلى بريد إلكتروني مختلف. سجّل الدخول بالبريد المدعو.';
  end if;

  update public.invitations
  set declined_at = now(), updated_at = now()
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
  auth_user auth.users%rowtype;
  current_email text;
  current_church_id uuid;
  invited_name text;
  invited_phone text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into inv
  from public.invitations
  where invite_token = btrim(p_token)
  for update;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;
  if inv.declined_at is not null then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  select * into auth_user from auth.users where id = auth.uid();
  current_email := lower(btrim(auth_user.email));

  if nullif(lower(btrim(inv.email)), '') is null
     or lower(btrim(inv.email)) = 'no-email@linkapp.local' then
    if nullif(current_email, '') is null
       or current_email = 'no-email@linkapp.local' then
      raise exception 'أدخل بريدك الإلكتروني الحقيقي لإكمال الدعوة.';
    end if;
  elsif current_email is distinct from lower(btrim(inv.email)) then
    raise exception 'هذه الدعوة موجهة إلى بريد إلكتروني مختلف. سجّل الدخول بالبريد المدعو.';
  end if;

  select church_id into current_church_id
  from public.profiles where id = auth.uid();

  if inv.is_used then
    if current_church_id = inv.church_id then
      return inv.church_id;
    end if;
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  if current_church_id is not null and current_church_id <> inv.church_id then
    raise exception 'هذا الحساب مرتبط بكنيسة أخرى بالفعل. استخدم حسابًا غير مرتبط بكنيسة.';
  end if;

  invited_name := coalesce(
    nullif(btrim(auth_user.raw_user_meta_data ->> 'full_name'), ''),
    inv.full_name
  );
  invited_phone := nullif(btrim(auth_user.raw_user_meta_data ->> 'phone'), '');

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    auth.uid(), inv.church_id, invited_name, inv.role, current_email, invited_phone
  )
  on conflict (id) do update
  set church_id = excluded.church_id,
      role = excluded.role,
      email = coalesce(excluded.email, public.profiles.email),
      full_name = coalesce(nullif(btrim(public.profiles.full_name), ''), excluded.full_name),
      phone = coalesce(public.profiles.phone, excluded.phone),
      updated_at = now();

  perform public.accept_invitation_assignment(inv.id, auth.uid());
  return inv.church_id;
end;
$$;

revoke all on function public.accept_invitation_link(text) from public, anon;
grant execute on function public.accept_invitation_link(text) to authenticated;
