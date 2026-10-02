import Link from 'next/link';
import { getMeetingGroupsData } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';

const number = (value: number) => new Intl.NumberFormat('ar-EG').format(value);

export default async function MeetingGroupsPage({
  searchParams,
}: {
  searchParams: Promise<{ church?: string; q?: string; page?: string }>;
}) {
  await requireSuperAdmin();
  const search = await searchParams;
  const { churches, groups } = await getMeetingGroupsData(search.church || undefined);
  const query = (search.q ?? '').trim().toLocaleLowerCase('ar');
  const matchingGroups = groups.filter((group) => !query ||
    `${group.church} ${group.meeting} ${group.servants.join(' ')} ${group.members.join(' ')}`
      .toLocaleLowerCase('ar').includes(query));
  const pageSize = 12;
  const pages = Math.max(1, Math.ceil(matchingGroups.length / pageSize));
  const page = Math.min(pages, Math.max(1, Number.parseInt(search.page ?? '1', 10) || 1));
  const visibleGroups = matchingGroups.slice((page - 1) * pageSize, page * pageSize);
  const pageHref = (nextPage: number) => `/admin/groups?${new URLSearchParams({
    ...(search.church ? { church: search.church } : {}),
    ...(search.q ? { q: search.q } : {}),
    page: String(nextPage),
  }).toString()}`;

  return (
    <main className="adminContent groupsPage">
      <div className="pageTitle dataTitle">
        <div><span>إدارة الخدمة</span><h1>المجموعات حسب الاجتماع والكنيسة</h1><p>الاجتماعات والخدام المسؤولون والمخدومون في كل مجموعة.</p></div>
        <div className="recordCount">{number(matchingGroups.length)} اجتماع</div>
      </div>

      <form className="groupsFilters" method="get">
        <label>الكنيسة<select name="church" defaultValue={search.church ?? ''}><option value="">كل الكنائس</option>{churches.map((church) => <option key={String(church.id)} value={String(church.id)}>{String(church.name_ar || church.name || 'كنيسة بلا اسم')}</option>)}</select></label>
        <label className="groupSearch">بحث<input name="q" type="search" defaultValue={search.q ?? ''} placeholder="اسم الاجتماع أو الخادم أو المخدوم…" /></label>
        <button type="submit">تطبيق</button>
      </form>

      {visibleGroups.length ? <div className="meetingGroupsGrid">{visibleGroups.map((group) => (
        <article key={group.id} className="meetingGroup">
          <div className="meetingGroupTitle"><div><small>{group.church}</small><h3>{group.meeting}</h3></div><strong>{number(group.memberCount)}<small>مخدوم نشط</small></strong></div>
          <div className="meetingGroupServants"><b>الخدام المسؤولون</b><span>{group.servants.length ? group.servants.join('، ') : 'لا يوجد خدام مكلّفون مسجلون'}</span></div>
          <details><summary>عرض أسماء المخدومين ({number(group.memberCount)})</summary>{group.members.length ? <ul>{group.members.map((member, index) => <li key={`${group.id}-${member}-${index}`}>{member}</li>)}</ul> : <p>لا يوجد مخدومون نشطون مرتبطون بهذا الاجتماع.</p>}</details>
        </article>
      ))}</div> : <div className="emptyMetric">مفيش مجموعات مطابقة للبحث والكنيسة المختارة.</div>}

      {matchingGroups.length > pageSize && <footer className="groupsPagination"><span>صفحة {number(page)} من {number(pages)}</span><div>{page > 1 && <Link href={pageHref(page - 1)}>السابق</Link>}{page < pages && <Link href={pageHref(page + 1)}>التالي</Link>}</div></footer>}
    </main>
  );
}
