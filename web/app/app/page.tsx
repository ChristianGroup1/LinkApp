import Image from 'next/image';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { logoutFromWebApp } from './actions';
import { InstallPrompt } from './install-prompt';

const roleLabels: Record<string, string> = {
  super_admin: 'مالك النظام',
  church_admin: 'مسؤول الكنيسة',
  class_leader: 'أمين فصل',
  attendance_officer: 'مسؤول حضور',
};

export default async function LinkWebAppPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/app/login');

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, role, is_active')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile?.is_active) {
    await supabase.auth.signOut();
    redirect('/app/login?error=not-authorized');
  }

  return (
    <main className="pwaAppPage">
      <header className="pwaAppHeader">
        <Link href="/" className="pwaLogo"><Image src="/link-logo.png" alt="Link" width={42} height={42} /><span>Link</span></Link>
        <form action={logoutFromWebApp}><button className="pwaLogout" type="submit">تسجيل الخروج</button></form>
      </header>
      <section className="pwaWelcome">
        <p>مرحبًا، {profile.full_name}</p>
        <h1>مساحة الخدمة</h1>
        <span>{roleLabels[profile.role] ?? 'خادم'}</span>
        <InstallPrompt />
      </section>
      <section className="pwaActions" aria-label="أدوات Link Web">
        <article><span>✓</span><h2>الحضور</h2><p>سجّل حضور الاجتماع من تطبيق Link على الهاتف أو الكمبيوتر.</p></article>
        <article><span>◫</span><h2>الأعضاء</h2><p>البيانات والتحديثات تُحفظ في نفس حساب Link الخاص بك.</p></article>
        <article><span>↻</span><h2>المزامنة</h2><p>اتصل بالإنترنت لتصل أحدث التغييرات بأمان.</p></article>
      </section>
      {profile.role === 'super_admin' && <Link className="pwaAdminLink" href="/admin">فتح لوحة مالك النظام</Link>}
      <p className="pwaNote">نسخة الويب جاهزة للتثبيت. ميزات الخدمة التفصيلية ستظهر هنا تدريجيًا بنفس الصلاحيات والبيانات.</p>
    </main>
  );
}
