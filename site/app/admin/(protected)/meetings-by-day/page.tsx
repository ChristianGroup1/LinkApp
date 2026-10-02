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
    && (!query || `${meeting.name} ${meeting.church} ${meeting.servants.map((servant) => `${servant.name} ${servant.phone ?? ''}`).join(' ')}`.toLocaleLowerCase('ar').includes(query)),
  );

  return (
    <main className="adminContent meetingsByDayPage">
      <div className="pageTitle dataTitle">
        <div><span>إدارة الاجتماعات</span><h1>الاجتماعات حسب اليوم</h1><p>كل يوم وتحته اجتماعاته، وعدد المخدومين، والخدام المكلّفون وأرقامهم المسجلة.</p></div>
        <div className="recordCount">{number(meetings.length)} اجتماع</div>
      </div>

      <form className="groupsFilters meetingsDayFilters" method="get">
        <label>اليوم<select name="day" defaultValue={search.day ?? ''}><option value="">كل الأيام</option>{adminWeekdayNames.map((day, index) => <option key={day} value={index + 1}>{day}</option>)}</select></label>
        <label>بحث بالاجتماع أو الكنيسة أو الخادم<input name="q" type="search" defaultValue={search.q ?? ''} placeholder="اسم الاجتماع أو الخادم أو رقم التليفون…" /></label>
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
                  <details className="meetingServantsDetails">
                    <summary>الخدام وأرقام التليفون ({number(meeting.servants.length)})</summary>
                    {meeting.servants.length ? <ul>{meeting.servants.map((servant, servantIndex) => {
                      const dialable = servant.phone?.replace(/[^\d+]/g, '');
                      return <li key={`${meeting.id}-${servant.name}-${servantIndex}`}><strong>{servant.name}</strong>{servant.phone ? <a href={`tel:${dialable}`} dir="ltr">{servant.phone}</a> : <span>لا يوجد رقم مسجل</span>}</li>;
                    })}</ul> : <p>لا يوجد خدام مكلّفون بهذا الاجتماع.</p>}
                  </details>
                </article>
              ))}</div> : <p className="meetingsDayEmpty">لا توجد اجتماعات مسجلة لهذا اليوم.</p>}
            </section>
          );
        })}
      </div>
    </main>
  );
}
