import type { Metadata } from 'next';
import Link from 'next/link';
import type { CSSProperties } from 'react';

export const metadata: Metadata = {
  title: 'Link Support | دعم تطبيق لينك',
  description:
    'Official support and contact information for the Link church management app.',
};

export default function SupportPage() {
  return (
    <main style={styles.page}>
      <section style={styles.card}>
        <span style={styles.badge}>Link Support</span>
        <h1 style={styles.title}>دعم تطبيق لينك</h1>
        <p style={styles.lead}>
          نحن هنا لمساعدتك في تسجيل الدخول، الدعوات، إدارة الاجتماعات، الحضور،
          والإشعارات.
        </p>

        <div style={styles.section}>
          <h2 style={styles.heading}>تواصل معنا</h2>
          <p style={styles.text}>
            أرسل وصف المشكلة، نوع جهازك، وإصدار التطبيق. نرد عادة خلال يومي عمل.
          </p>
          <a href="mailto:fadykhayrat@gmail.com" style={styles.email}>
            fadykhayrat@gmail.com
          </a>
        </div>

        <div style={styles.section}>
          <h2 style={styles.heading}>حذف الحساب والبيانات</h2>
          <p style={styles.text}>
            يمكنك حذف حسابك نهائياً من داخل التطبيق على Android وiOS وWindows
            عبر: الإعدادات ← الحساب ← حذف الحساب نهائياً، ثم تأكيد الحذف من
            النافذة. لا تحتاج كتابة أي جملة للتأكيد.
          </p>
          <p style={styles.text}>
            لو أنت المدير النشط الوحيد، يتم حذف بيانات الخدمة بالكامل مع
            حسابك. لو في مدير تاني نشط، يُحذف حسابك أنت فقط وتبقى بيانات
            الخدمة.
          </p>
          <p style={styles.text}>
            للمساعدة في طلبات الخصوصية أو إذا تعذر الحذف من التطبيق، تواصل
            معنا عبر البريد أعلاه.
          </p>
        </div>

        <div style={styles.links}>
          <Link href="/privacy-policy" style={styles.link}>
            سياسة الخصوصية
          </Link>
          <Link href="/" style={styles.link}>
            الصفحة الرئيسية
          </Link>
        </div>

        <hr style={styles.divider} />

        <div lang="en" dir="ltr">
          <h2 style={styles.heading}>English support</h2>
          <p style={styles.text}>
            For help with your account or the Link app, email us at{' '}
            <a href="mailto:fadykhayrat@gmail.com" style={styles.inlineLink}>
              fadykhayrat@gmail.com
            </a>
            . Please include your device model, app version, and a description
            of the issue. We usually respond within two business days.
          </p>
        </div>
      </section>
    </main>
  );
}

const styles: Record<string, CSSProperties> = {
  page: {
    minHeight: '100vh',
    padding: '48px 20px',
    background: 'linear-gradient(145deg, #eef2ff 0%, #f8fafc 55%, #ffffff 100%)',
    color: '#172033',
    direction: 'rtl',
    fontFamily:
      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Tahoma, Arial, sans-serif",
  },
  card: {
    maxWidth: '760px',
    margin: '0 auto',
    padding: 'clamp(24px, 5vw, 48px)',
    border: '1px solid #e2e8f0',
    borderRadius: '28px',
    background: '#ffffff',
    boxShadow: '0 24px 70px rgba(49, 46, 129, 0.10)',
  },
  badge: {
    display: 'inline-block',
    padding: '7px 14px',
    borderRadius: '999px',
    background: '#e0e7ff',
    color: '#4338ca',
    fontWeight: 800,
    fontSize: '13px',
  },
  title: {
    margin: '18px 0 10px',
    color: '#1e1b4b',
    fontSize: 'clamp(32px, 7vw, 48px)',
    lineHeight: 1.2,
  },
  lead: {
    margin: '0 0 32px',
    color: '#475569',
    fontSize: '18px',
    lineHeight: 1.9,
  },
  section: {
    marginTop: '22px',
    padding: '22px',
    borderRadius: '18px',
    background: '#f8fafc',
    border: '1px solid #eef2f7',
  },
  heading: {
    margin: '0 0 8px',
    color: '#1e293b',
    fontSize: '20px',
  },
  text: {
    margin: 0,
    color: '#475569',
    fontSize: '15px',
    lineHeight: 1.85,
  },
  email: {
    display: 'inline-block',
    marginTop: '14px',
    color: '#4338ca',
    fontWeight: 800,
    direction: 'ltr',
  },
  inlineLink: {
    color: '#4338ca',
    fontWeight: 700,
  },
  links: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '12px',
    marginTop: '26px',
  },
  link: {
    padding: '10px 16px',
    borderRadius: '12px',
    background: '#4338ca',
    color: '#ffffff',
    textDecoration: 'none',
    fontWeight: 700,
  },
  divider: {
    margin: '30px 0',
    border: 0,
    borderTop: '1px solid #e2e8f0',
  },
};
