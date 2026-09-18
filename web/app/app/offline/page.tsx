import Link from 'next/link';

export default function OfflinePage() {
  return <main className="pwaOffline"><h1>أنت غير متصل الآن</h1><p>ارجع للإنترنت ثم أعد فتح Link لمتابعة أحدث بيانات الخدمة.</p><Link href="/app">إعادة المحاولة</Link></main>;
}
