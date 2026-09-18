import Image from 'next/image';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { loginAction } from '../actions';

const errors: Record<string, string> = {
  'invalid-login': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  'email-not-confirmed': 'البريد الإلكتروني غير مؤكد. فعّل الحساب من Supabase أو من رسالة التأكيد ثم حاول مرة أخرى.',
  'rate-limited': 'تم إجراء محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
  'not-authorized': 'هذه اللوحة متاحة لحساب مالك النظام فقط.',
};

export default async function AdminLoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const params = await searchParams;
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (user) {
    const { data: profile } = await supabase.from('profiles').select('role, is_active').eq('id', user.id).maybeSingle();
    if (profile?.is_active && profile.role === 'super_admin') redirect('/admin');
  }

  return (
    <main className="adminLogin">
      <section className="loginCard">
        <div className="loginBrand">
          <Image src="/link-logo.png" alt="Link" width={70} height={70} priority />
          <div><strong>Link Control</strong><span>لوحة مالك النظام</span></div>
        </div>
        <h1>تسجيل دخول الإدارة</h1>
        <p>استخدم حساب <b>super_admin</b> النشط للوصول إلى الإحصائيات وإدارة البيانات.</p>
        {params.error && <div className="adminAlert error">{errors[params.error] ?? 'تعذر تسجيل الدخول.'}</div>}
        <form action={loginAction} className="loginForm">
          <label>البريد الإلكتروني<input type="email" name="email" required autoComplete="email" /></label>
          <label>كلمة المرور<input type="password" name="password" required autoComplete="current-password" /></label>
          <button type="submit">دخول آمن</button>
        </form>
        <Link className="backToSite" href="/">العودة إلى موقع Link</Link>
      </section>
    </main>
  );
}
