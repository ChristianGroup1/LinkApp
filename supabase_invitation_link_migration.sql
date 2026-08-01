-- ============================================================
-- Link: Invitation links (accept / decline via deep link)
-- Run in Supabase SQL Editor on existing projects.
-- ============================================================

alter table public.invitations
  add column if not exists invite_token text,
  add column if not exists declined_at timestamptz;

update public.invitations
set invite_token = encode(gen_random_bytes(24), 'hex')
where invite_token is null;

alter table public.invitations
  alter column invite_token set not null;

create unique index if not exists idx_invitations_invite_token
  on public.invitations (invite_token);

create index if not exists idx_invitations_pending
  on public.invitations (church_id)
  where is_used = false and declined_at is null;

create or replace function public.get_invitation_by_token(p_token text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  inv record;
  church_name text;
begin
  if nullif(btrim(p_token), '') is null then
    return jsonb_build_object('valid', false);
  end if;

  select i.*, c.name_ar as church_name_ar
  into inv
  from public.invitations i
  join public.churches c on c.id = i.church_id
  where i.invite_token = btrim(p_token)
  limit 1;

  if not found then
    return jsonb_build_object('valid', false);
  end if;

  if inv.is_used then
    return jsonb_build_object('valid', false, 'status', 'used');
  end if;

  if inv.declined_at is not null then
    return jsonb_build_object('valid', false, 'status', 'declined');
  end if;

  return jsonb_build_object(
    'valid', true,
    'status', 'pending',
    'invitation_id', inv.id,
    'church_id', inv.church_id,
    'church_name', inv.church_name_ar,
    'invitee_name', inv.full_name,
    'email', inv.email,
    'role', inv.role,
    'assignment_scope', inv.assignment_scope,
    'can_take_attendance', coalesce(inv.can_take_attendance, true),
    'can_view_reports', coalesce(inv.can_view_reports, true)
  );
end;
$$;

grant execute on function public.get_invitation_by_token(text) to anon, authenticated;

create or replace function public.decline_invitation_by_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  inv_id uuid;
begin
  select id
  into inv_id
  from public.invitations
  where invite_token = btrim(p_token)
    and is_used = false
    and declined_at is null
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  update public.invitations
  set declined_at = now()
  where id = inv_id;
end;
$$;

grant execute on function public.decline_invitation_by_token(text) to anon, authenticated;

create or replace function public.accept_invitation_link(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  inv record;
  profile_church_id uuid;
begin
  if auth.uid() is null then
    raise exception 'يجب تسجيل الدخول أولاً';
  end if;

  select *
  into inv
  from public.invitations
  where invite_token = btrim(p_token)
    and is_used = false
    and declined_at is null
  limit 1;

  if not found then
    raise exception 'الدعوة غير صالحة أو انتهت صلاحيتها.';
  end if;

  select church_id
  into profile_church_id
  from public.profiles
  where id = auth.uid();

  if profile_church_id is null then
    raise exception 'أكمل إنشاء حسابك أولاً من شاشة التسجيل.';
  end if;

  if profile_church_id <> inv.church_id then
    raise exception 'هذا الحساب مرتبط بكنيسة أخرى.';
  end if;

  perform public.accept_invitation_assignment(inv.id, auth.uid());

  return inv.church_id;
end;
$$;

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

  select *
  into inv
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

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    inv.church_id,
    normalized_full_name,
    inv.role,
    nullif(btrim(profile_email), ''),
    nullif(btrim(profile_phone), '')
  )
  returning church_id into profile_church_id;

  perform public.accept_invitation_assignment(inv.id, profile_id);

  return profile_church_id;
end;
$$;

grant execute on function public.register_invited_signup(uuid, text, text, text, text, text) to authenticated;
