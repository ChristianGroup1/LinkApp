import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export type AdminIdentity = {
  id: string;
  email: string;
  fullName: string;
};

export async function requireSuperAdmin(): Promise<AdminIdentity> {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) redirect('/admin/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, role, is_active')
    .eq('id', user.id)
    .maybeSingle();

  if (!profile?.is_active || profile.role !== 'super_admin') {
    await supabase.auth.signOut();
    redirect('/admin/login?error=not-authorized');
  }

  return {
    id: user.id,
    email: user.email ?? '',
    fullName: profile.full_name,
  };
}

