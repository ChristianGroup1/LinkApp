import Image from 'next/image';
import Link from 'next/link';
import { loginToWebApp } from '../actions';

const errors: Record<string, string> = {
  'invalid-login': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  'not-authorized': 'هذا الحساب غير نشط أو ليس له صلاحية دخول.',
};

export default async function WebAppLoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const params = await searchParams;

  return (
    <main className="pwaLoginPage">
      <section className="pwaLoginCard">
        <Link href="/" className="pwaLogo"><Image src="/link-logo.png" alt="Link" width={56} height={56} /><span>Link Web</span></Link>
        <h1>أهلًا بك</h1>
        <p>ادخل بحسابك الحالي في تطبيق Link.</p>
        {params.error && <p className="pwaError" role="alert">{errors[params.error] ?? 'تعذر تسجيل الدخول.'}</p>}
        <form action={loginToWebApp} className="pwaLoginForm">
          <label>البريد الإلكتروني<input name="email" type="email" autoComplete="email" required /></label>
          <label>كلمة المرور<input name="password" type="password" autoComplete="current-password" required /></label>
          <button type="submit">دخول</button>
        </form>
        <Link href="/" className="pwaBackLink">العودة إلى الموقع</Link>
      </section>
    </main>
  );
}
