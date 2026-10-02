-- Invitations without a supplied email store NULL. Legacy placeholder values
-- remain recognized while they are cleaned up below.

-- New invitations store a missing email as NULL; clean up placeholder values
-- created by older app versions. The client still recognizes them during the
-- transition period.
update public.invitations
set email = null, updated_at = now()
where lower(btrim(email)) = 'no-email@linkapp.local';

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
    and declined_at is null
  limit 1;

  if not found then
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
  set declined_at = now()
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
  current_email text;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select * into inv
  from public.invitations
  where invite_token = btrim(p_token)
    and declined_at is null
  limit 1;

  if not found then
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

  -- A signup can finish the invitation assignment before the client receives
  -- the response. Treat the follow-up accept call as successful for that same
  -- church profile so the user is not stranded on a duplicate-invite error.
  if inv.is_used then
    if exists (
      select 1 from public.profiles
      where id = auth.uid() and church_id = inv.church_id
    ) then
      return inv.church_id;
    end if;
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  update public.profiles
  set church_id = inv.church_id,
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'أكمل إنشاء حسابك أولاً من شاشة التسجيل.';
  end if;

  perform public.accept_invitation_assignment(inv.id, auth.uid());
  return inv.church_id;
end;
$$;

revoke all on function public.accept_invitation_link(text) from public, anon;
grant execute on function public.accept_invitation_link(text) to authenticated;

create or replace function public.register_invited_signup(
  profile_id uuid,
  invite_code text default null,
  invite_token text default null,
  profile_full_name text default null,
  profile_email text default null,
  profile_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
  normalized_full_name text := nullif(btrim(profile_full_name), '');
  profile_church_id uuid;
  normalized_code text := nullif(upper(btrim(invite_code)), '');
  normalized_token text := nullif(btrim(invite_token), '');
  current_email text;
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_full_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if normalized_code is null and normalized_token is null then
    raise exception 'رابط أو كود الدعوة مطلوب';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  select * into inv
  from public.invitations
  where is_used = false
    and declined_at is null
    and (
      (normalized_token is not null and invite_token = normalized_token)
      or (normalized_code is not null and upper(btrim(code)) = normalized_code)
    )
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو تم استخدامها أو رفضها.';
  end if;

  if normalized_token is not null then
    select lower(btrim(email)) into current_email
    from auth.users where id = auth.uid();

    if nullif(lower(btrim(inv.email)), '') is null
       or lower(btrim(inv.email)) = 'no-email@linkapp.local' then
      if nullif(current_email, '') is null
         or current_email = 'no-email@linkapp.local'
         or lower(btrim(profile_email)) is distinct from current_email then
        raise exception 'أدخل بريدك الإلكتروني الحقيقي لإكمال الدعوة.';
      end if;
    elsif current_email is distinct from lower(btrim(inv.email))
       or lower(btrim(profile_email)) is distinct from lower(btrim(inv.email)) then
      raise exception 'يجب إنشاء الحساب بنفس البريد الإلكتروني المكتوب في الدعوة.';
    end if;
  end if;

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    inv.church_id,
    normalized_full_name,
    inv.role,
    coalesce(current_email, nullif(lower(btrim(profile_email)), '')),
    nullif(btrim(profile_phone), '')
  )
  returning church_id into profile_church_id;

  perform public.accept_invitation_assignment(inv.id, profile_id);
  return profile_church_id;
end;
$$;

revoke all on function public.register_invited_signup(uuid, text, text, text, text, text)
  from public, anon;
grant execute on function public.register_invited_signup(uuid, text, text, text, text, text)
  to authenticated;
