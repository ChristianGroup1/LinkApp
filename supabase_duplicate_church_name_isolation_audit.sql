-- Read-only verification for the duplicate church-name isolation hotfix.
-- Run this in Supabase SQL Editor after applying the hotfix.

-- Expected after the hotfix: new_church_rpc_anon and both legacy helper
-- permissions are false, while new_church_rpc_authenticated is true.
select
  has_function_privilege(
    'anon',
    'public.register_new_church_signup(uuid,text,text,text,text)',
    'execute'
  ) as new_church_rpc_anon,
  has_function_privilege(
    'authenticated',
    'public.register_new_church_signup(uuid,text,text,text,text)',
    'execute'
  ) as new_church_rpc_authenticated,
  has_function_privilege(
    'authenticated',
    'public.ensure_church(text)',
    'execute'
  ) as legacy_ensure_church_authenticated,
  has_function_privilege(
    'authenticated',
    'public.create_signup_profile(uuid,uuid,text,public.app_role,text,text)',
    'execute'
  ) as legacy_create_profile_authenticated;

-- Any rows returned here are accounts that probably collided before the fix:
-- more than one independent "new church" signup currently points at one
-- church_id. Review these rows before moving data or changing church_id.
with new_church_signups as (
  select
    p.id as user_id,
    p.church_id,
    c.name_ar as church_name,
    coalesce(p.email, u.email) as email,
    p.full_name,
    p.created_at,
    u.raw_user_meta_data ->> 'church_name' as requested_church_name
  from public.profiles p
  join public.churches c on c.id = p.church_id
  join auth.users u on u.id = p.id
  where u.raw_user_meta_data ->> 'signup_type' = 'new_church'
), collided_churches as (
  select church_id
  from new_church_signups
  group by church_id
  having count(*) > 1
)
select s.*
from new_church_signups s
join collided_churches c using (church_id)
order by s.church_id, s.created_at, s.user_id;
