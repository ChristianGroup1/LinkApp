'use server';

import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';

export async function loginToWebApp(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.user) redirect('/app/login?error=invalid-login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('is_active')
    .eq('id', data.user.id)
    .maybeSingle();

  if (!profile?.is_active) {
    await supabase.auth.signOut();
    redirect('/app/login?error=not-authorized');
  }

  redirect('/app');
}

export async function logoutFromWebApp() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect('/app/login');
}
