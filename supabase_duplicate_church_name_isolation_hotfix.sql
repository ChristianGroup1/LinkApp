-- ============================================================
-- Link: duplicate church-name tenant isolation hotfix
--
-- Apply to the existing Supabase project without resetting data.
-- Two churches may have the same display name, but they must always receive
-- different IDs and completely independent data. Joining an existing church
-- is allowed only through the invitation RPC.
-- ============================================================

begin;

create or replace function public.register_new_church_signup(
  profile_id uuid,
  church_name text,
  profile_full_name text,
  profile_email text,
  profile_phone text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_name text := nullif(btrim(church_name), '');
  normalized_full_name text := nullif(btrim(profile_full_name), '');
  target_church_id uuid;
begin
  if auth.uid() is null or auth.uid() <> profile_id then
    raise exception 'غير مصرح بإكمال التسجيل';
  end if;

  if normalized_name is null then
    raise exception 'اسم الكنيسة مطلوب';
  end if;

  if normalized_full_name is null then
    raise exception 'اسم المستخدم مطلوب';
  end if;

  if exists (select 1 from public.profiles where id = profile_id) then
    raise exception 'الحساب مربوط بكنيسة بالفعل';
  end if;

  -- Never search by name here. A duplicate display name is valid and must
  -- create a new tenant. The random UUID-derived slug is only a technical key.
  insert into public.churches (name, name_ar, slug)
  values (
    normalized_name,
    normalized_name,
    'church-' || replace(gen_random_uuid()::text, '-', '')
  )
  returning id into target_church_id;

  insert into public.profiles (id, church_id, full_name, role, email, phone)
  values (
    profile_id,
    target_church_id,
    normalized_full_name,
    'church_admin',
    nullif(btrim(profile_email), ''),
    nullif(btrim(profile_phone), '')
  );

  return target_church_id;
end;
$$;

revoke all on function public.register_new_church_signup(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.register_new_church_signup(uuid, text, text, text, text)
  to authenticated;

-- The older helper can join tenants by display name, so it must never be
-- callable from client roles. Existing server-side ownership is preserved.
revoke all on function public.ensure_church(text) from public, anon, authenticated;
revoke all on function public.create_signup_profile(
  uuid,
  uuid,
  text,
  public.app_role,
  text,
  text
) from public, anon, authenticated;

commit;
