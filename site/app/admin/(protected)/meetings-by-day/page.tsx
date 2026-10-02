import { getMeetingsByWeekdayData } from '@/lib/admin/data';
import { adminWeekdayNames } from '@/lib/admin/labels';
import { requireSuperAdmin } from '@/lib/admin/auth';

const number = (value: number) => new Intl.NumberFormat('ar-EG').format(value);

export default async function MeetingsByDayPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; day?: string }>;
}) {
  await requireSuperAdmin();
  const search = await searchParams;
  const allMeetings = await getMeetingsByWeekdayData();
  const query = (search.q ?? '').trim().toLocaleLowerCase('ar');
  const selectedDay = Number(search.day ?? '0');
  const meetings = allMeetings.filter((meeting) =>
    (!Number.isInteger(selectedDay) || selectedDay < 1 || selectedDay > 7 || meeting.weekday === selectedDay)
    && (!query || `${meeting.name} ${meeting.church} ${meeting.creator?.name ?? ''} ${meeting.creator?.phone ?? ''}`.toLocaleLowerCase('ar').includes(query)),
  );

  return (
    <main className="adminContent meetingsByDayPage">
      <div className="pageTitle dataTitle">
        <div><span>إدارة الاجتماعات</span><h1>الاجتماعات حسب اليوم</h1><p>كل يوم وتحته اجتماعاته، وعدد المخدومين، واسم منشئ الاجتماع ورقمه المسجل.</p></div>
        <div className="recordCount">{number(meetings.length)} اجتماع</div>
      </div>

      <form className="groupsFilters meetingsDayFilters" method="get">
        <label>اليوم<select name="day" defaultValue={search.day ?? ''}><option value="">كل الأيام</option>{adminWeekdayNames.map((day, index) => <option key={day} value={index + 1}>{day}</option>)}</select></label>
        <label>بحث بالاجتماع أو الكنيسة أو المنشئ<input name="q" type="search" defaultValue={search.q ?? ''} placeholder="اسم الاجتماع أو المنشئ أو رقم التليفون…" /></label>
        <button type="submit">تطبيق</button>
      </form>

      <div className="meetingsByDayList">
        {adminWeekdayNames.map((day, index) => {
          const dayMeetings = meetings.filter((meeting) => meeting.weekday === index + 1);
          if (selectedDay >= 1 && selectedDay <= 7 && selectedDay !== index + 1) return null;
          return (
            <section className="meetingsDaySection" key={day}>
              <header><h2>{day}</h2><span>{number(dayMeetings.length)} اجتماع</span></header>
              {dayMeetings.length ? <div className="meetingsDayGrid">{dayMeetings.map((meeting) => (
                <article className="meetingsDayCard" key={meeting.id}>
                  <div><h3>{meeting.name}</h3><p>{meeting.church}</p></div>
                  <div className="meetingDayBadges"><span className="meetingMembersCount">{number(meeting.memberCount)} مخدوم نشط</span><span className={meeting.isActive ? 'statusActive' : 'statusQuiet'}>{meeting.isActive ? 'نشط' : 'متوقف'}</span></div>
                  <div className="meetingCreator"><small>منشئ الاجتماع</small>{meeting.creator ? <><strong>{meeting.creator.name}</strong>{meeting.creator.phone ? <a href={`tel:${meeting.creator.phone.replace(/[^\d+]/g, '')}`} dir="ltr">{meeting.creator.phone}</a> : <span>لا يوجد رقم مسجل</span>}</> : <span>بيانات المنشئ غير متاحة</span>}</div>
                </article>
              ))}</div> : <p className="meetingsDayEmpty">لا توجد اجتماعات مسجلة لهذا اليوم.</p>}
            </section>
          );
        })}
      </div>
    </main>
  );
}
