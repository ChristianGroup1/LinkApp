import Link from 'next/link';
import type { CSSProperties } from 'react';
import { getDashboardData } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';

function formatNumber(value: number) {
  return new Intl.NumberFormat('ar-EG').format(value);
}

function changeText(value: number) {
  return `${value >= 0 ? '+' : ''}${value}%`;
}

function TrendBars({ points }: { points: Array<{ date: string; count: number }> }) {
  const max = Math.max(1, ...points.map((point) => point.count));
  return (
    <div className="trendBars" aria-label="نشاط آخر 30 يومًا">
      {points.map((point) => (
        <i key={point.date} style={{ height: `${Math.max(4, (point.count / max) * 100)}%` }} title={`${point.date}: ${point.count}`} />
      ))}
    </div>
  );
}

export default async function AdminDashboardPage() {
  await requireSuperAdmin();
  const data = await getDashboardData();
  const { metrics } = data;
  const scoreLabel = metrics.successScore >= 75 ? 'أداء قوي' : metrics.successScore >= 50 ? 'نمو جيد' : 'يحتاج متابعة';

  return (
    <main className="adminContent">
      <div className="pageTitle">
        <div><span>لوحة القرار</span><h1>هل التطبيق ينجح؟</h1><p>قراءة مبنية على نشاط الاستخدام الفعلي خلال آخر 30 يومًا.</p></div>
        <div className="updatedAt">آخر تحديث {new Date(data.generatedAt).toLocaleString('ar-EG')}</div>
      </div>

      <section className="scorePanel">
        <div className="scoreRing" style={{ '--score': `${metrics.successScore * 3.6}deg` } as CSSProperties}>
          <span><strong>{metrics.successScore}</strong><small>/ 100</small></span>
        </div>
        <div><span className="scoreTag">{scoreLabel}</span><h2>مؤشر نجاح Link</h2><p>مزيج من تفعيل الكنائس، استمرار الاستخدام، ونمو جلسات الحضور.</p></div>
        <div className="scoreFactors">
          <span><b>{metrics.activationRate}%</b> تفعيل الكنائس</span>
          <span><b>{metrics.retentionRate}%</b> استمرار الاستخدام</span>
          <span><b>{changeText(metrics.engagementChange)}</b> تغير النشاط</span>
        </div>
      </section>

      <section className="metricGrid">
        <article><span className="metricIcon purple">♜</span><small>الكنائس</small><strong>{formatNumber(metrics.churchesTotal)}</strong><em>{metrics.activationRate}% نشطة هذا الشهر</em></article>
        <article><span className="metricIcon teal">♙</span><small>المستخدمون النشطون</small><strong>{formatNumber(metrics.profilesActive)}</strong><em>{changeText(metrics.userGrowth)} مستخدم جديد</em></article>
        <article><span className="metricIcon amber">✓</span><small>جلسات الحضور / 30 يوم</small><strong>{formatNumber(metrics.sessionsCurrent)}</strong><em>{changeText(metrics.engagementChange)} عن الفترة السابقة</em></article>
        <article><span className="metricIcon blue">%</span><small>نسبة الحضور</small><strong>{metrics.attendanceRate}%</strong><em>من السجلات غير المعذورة</em></article>
        <article><span className="metricIcon purple">◉</span><small>المخدومون النشطون</small><strong>{formatNumber(metrics.membersActive)}</strong><em>{metrics.meetingsActive} اجتماع نشط</em></article>
        <article><span className="metricIcon teal">↗</span><small>نشطون آخر 7 أيام</small><strong>{data.analyticsReady ? formatNumber(metrics.activeUsers7) : '—'}</strong><em>{data.analyticsReady ? `${metrics.activeUsers30} خلال 30 يومًا` : 'فعّل Migration التتبع'}</em></article>
      </section>

      <section className="dashboardGrid">
        <article className="chartCard wide">
          <header><div><h2>نشاط جلسات الحضور</h2><p>عدد الجلسات يوميًا خلال آخر 30 يومًا</p></div><b>{metrics.sessionsCurrent}</b></header>
          <TrendBars points={data.sessionTrend} />
        </article>
        <article className="attentionCard">
          <header><h2>تحتاج انتباهك</h2><span>{metrics.pendingInvitations + metrics.pendingFollowUps}</span></header>
          <div><b>{metrics.pendingInvitations}</b><span>دعوة لم تُستخدم بعد</span><Link href="/admin/data/invitations">مراجعة ←</Link></div>
          <div><b>{metrics.pendingFollowUps}</b><span>حالة افتقاد غير مكتملة</span><Link href="/admin/data/follow_ups">مراجعة ←</Link></div>
        </article>
      </section>

      <section className="dashboardGrid">
        <article className="tableCard wide">
          <header><div><h2>أحدث الكنائس</h2><p>ملخص النشاط والاستخدام</p></div><Link href="/admin/data/churches">إدارة الكل</Link></header>
          <div className="simpleTable">
            <div className="tableHead"><span>الكنيسة</span><span>المستخدمون</span><span>جلسات 30 يوم</span><span>الحالة</span></div>
            {data.churchRows.map((church) => <div key={church.id}><strong>{church.name}</strong><span>{church.users}</span><span>{church.sessions30}</span><span className={church.active ? 'statusActive' : 'statusQuiet'}>{church.active ? 'نشطة' : 'هادئة'}</span></div>)}
          </div>
        </article>
        <article className="distributionCard">
          <h2>توزيع المنصات</h2><p>حسب أحداث الاستخدام المسجلة</p>
          {Object.keys(data.platformCounts).length ? Object.entries(data.platformCounts).map(([platform, count]) => (
            <div key={platform}><span>{platform}</span><b>{count}</b></div>
          )) : <div className="emptyMetric">سيظهر بعد تطبيق Migration التتبع ونشر تحديث التطبيق.</div>}
          <h3>الإصدارات المستخدمة</h3>
          {Object.entries(data.versionCounts).slice(0, 4).map(([version, count]) => <div key={version}><span>{version}</span><b>{count}</b></div>)}
        </article>
      </section>
    </main>
  );
}
