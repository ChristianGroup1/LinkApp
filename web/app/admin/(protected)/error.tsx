'use client';

export default function AdminError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="adminContent">
      <div className="adminSetupError">
        <span>!</span>
        <h1>تعذر تحميل بيانات لوحة الإدارة</h1>
        <p>تأكد من إضافة <b>SUPABASE_SERVICE_ROLE_KEY</b> إلى متغيرات بيئة Vercel، ثم طبّق ملف Migration الخاص بالداشبورد.</p>
        <button type="button" onClick={reset}>إعادة المحاولة</button>
      </div>
    </main>
  );
}

