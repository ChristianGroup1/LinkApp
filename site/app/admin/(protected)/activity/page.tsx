import { requireSuperAdmin } from '@/lib/admin/auth';
import { getActivityPageData } from '@/lib/admin/activity';
import type { ActivitySearch } from '@/lib/admin/activity-periods';

const n = (value: number) => new Intl.NumberFormat('ar-EG').format(value);

export default async function ActivityPage({ searchParams }: {
  searchParams: Promise<ActivitySearch & { church?: string }>;
}) {
  await requireSuperAdmin();
  const search = await searchParams;
  const { activity, totalUsers, churchUsers, churches } = await getActivityPageData(search, search.church || undefined);
  return <main className="adminContent enhancedDashboard">
    <div className="pageTitle"><div><span>إحصائيات المستخدمين</span><h1>نشاط المستخدمين</h1><p>إجمالي المستخدمين والنشاط حسب الفترة والكنيسة.</p></div></div>
    <section className="userActivityCard">
      <header><div><h2>المستخدمون النشطون</h2><p>كل مستخدم يُحسب مرة واحدة حسب فتح التطبيق أو تسجيل الدخول. التواريخ بتوقيت القاهرة.</p></div></header>
      <div className="metricGrid userActivityMetrics"><article><small>إجمالي المستخدمين — Total users</small><strong>{totalUsers === null ? '—' : n(totalUsers)}</strong><em>كل الحسابات المسجّلة، بما فيها الحسابات الموقوفة</em></article>{search.church && <article><small>مستخدمو الكنيسة المختارة</small><strong>{churchUsers === null ? '—' : n(churchUsers)}</strong><em>إجمالي الحسابات المسجّلة في الكنيسة</em></article>}{([
        ['recent', 'استخدموا التطبيق آخر ٥ دقائق', 'حسب الاستخدام المسجّل'],
        ['today', 'نشطون النهارده', 'من بداية اليوم بتوقيت القاهرة'],
        ['day', 'نشطون آخر يوم', 'آخر ٢٤ ساعة'],
        ['week', 'نشطون آخر أسبوع', 'آخر ٧ أيام'],
        ['month', 'نشطون آخر شهر', 'آخر ٣٠ يومًا'],
      ] as const).map(([key, label, hint]) => <article key={key}><small>{label}</small><strong>{activity.counts ? n(activity.counts[key]) : '—'}</strong><em>{hint}</em></article>)}</div>
      <form className="userActivityFilters" method="get">
        <label>الكنيسة<select name="church" defaultValue={search.church ?? ''}><option value="">كل الكنائس</option>{churches.map((church) => <option key={church.id} value={church.id}>{church.name_ar || church.name}</option>)}</select></label>
        <label>فترة النشاط<select name="activity" defaultValue={activity.period}><option value="today">النهارده</option><option value="day">آخر يوم</option><option value="week">آخر أسبوع</option><option value="month">آخر شهر</option><option value="custom">فترة مخصصة</option></select></label>
        <label>من<input type="date" name="activityFrom" defaultValue={activity.from} max={activity.today} /></label>
        <label>إلى<input type="date" name="activityTo" defaultValue={activity.to} max={activity.today} /></label>
        <button type="submit">عرض النشاط</button>
      </form>
      {activity.error ? <p role="alert">{activity.error}</p> : <p className="activitySelectedCount">النشطون في الفترة المختارة: <strong>{activity.counts ? n(activity.counts.selected) : '—'}</strong></p>}
      {!activity.ready && <p role="alert">تعذر تحميل إحصائيات الاستخدام. أعد المحاولة لاحقًا.</p>}
      <p className="activityNote">اختر «فترة مخصصة» لاستخدام تاريخ البداية والنهاية. الإحصائيات تشمل الاستخدام المسجّل من الإصدارات التي ترسل أحداث النشاط.</p>
    </section>

    {totalUsers === null && <p role="alert">تعذر تحميل إجمالي المستخدمين.</p>}
  </main>;
}
