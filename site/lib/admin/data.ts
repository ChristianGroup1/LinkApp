import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { adminTables, type AdminTableConfig, type AdminTableKey } from '@/lib/admin/schema';

const DAY = 86_400_000;
const DASHBOARD_TIME_ZONE = 'Africa/Cairo';

function isoDate(date: Date) {
  return date.toISOString().slice(0, 10);
}

function dateKeyInDashboardTimeZone(value: string | Date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: DASHBOARD_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(typeof value === 'string' ? new Date(value) : value);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((item) => item.type === type)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function percentChange(current: number, previous: number) {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100);
}

function dayBuckets(rows: Array<Record<string, unknown>>, field: string, days = 30) {
  const now = new Date();
  return Array.from({ length: days }, (_, index) => {
    const date = new Date(now.getTime() - (days - index - 1) * DAY);
    const key = isoDate(date);
    return {
      date: key,
      count: rows.filter((row) => String(row[field] ?? '').slice(0, 10) === key).length,
    };
  });
}

type CountFilter =
  | { operation: 'eq' | 'gte' | 'lt'; column: string; value: string | number | boolean }
  | { operation: 'is'; column: string; value: null | boolean }
  | { operation: 'in'; column: string; value: string[] };

async function exactCount(table: string, filters: CountFilter[] = []) {
  const admin = createSupabaseAdminClient();
  let query = admin.from(table).select('*', { count: 'exact', head: true });
  for (const filter of filters) {
    if (filter.operation === 'eq') query = query.eq(filter.column, filter.value);
    if (filter.operation === 'gte') query = query.gte(filter.column, filter.value);
    if (filter.operation === 'lt') query = query.lt(filter.column, filter.value);
    if (filter.operation === 'is') query = query.is(filter.column, filter.value);
    if (filter.operation === 'in') query = query.in(filter.column, filter.value);
  }
  const { count, error } = await query;
  if (error) throw error;
  return count ?? 0;
}

export async function getDashboardData() {
  const admin = createSupabaseAdminClient();
  const now = new Date();
  const currentStart = new Date(now.getTime() - 30 * DAY);
  const previousStart = new Date(now.getTime() - 60 * DAY);
  const currentIso = currentStart.toISOString();
  const previousIso = previousStart.toISOString();
  const currentDate = isoDate(currentStart);
  const previousDate = isoDate(previousStart);
  const todayKey = dateKeyInDashboardTimeZone(now);

  const [
    churchesTotal,
    profilesActive,
    membersActive,
    meetingsActive,
    sessionsCurrent,
    sessionsPrevious,
    pendingInvitations,
    pendingFollowUps,
    churchesResult,
    profilesResult,
    sessionsResult,
    attendanceResult,
    usageResult,
  ] = await Promise.all([
    exactCount('churches'),
    exactCount('profiles', [{ operation: 'eq', column: 'is_active', value: true }]),
    exactCount('members', [{ operation: 'eq', column: 'is_active', value: true }]),
    exactCount('meetings', [{ operation: 'eq', column: 'is_active', value: true }]),
    exactCount('attendance_sessions', [{ operation: 'gte', column: 'session_date', value: currentDate }]),
    exactCount('attendance_sessions', [
      { operation: 'gte', column: 'session_date', value: previousDate },
      { operation: 'lt', column: 'session_date', value: currentDate },
    ]),
    exactCount('invitations', [
      { operation: 'eq', column: 'is_used', value: false },
      { operation: 'is', column: 'declined_at', value: null },
    ]),
    exactCount('follow_ups', [{ operation: 'in', column: 'contact_status', value: ['pending', 'contacted', 'no_response'] }]),
    admin.from('churches').select('id, name_ar, slug, created_at').order('created_at', { ascending: false }).limit(5000),
    admin.from('profiles').select('id, church_id, full_name, role, is_active, created_at').order('created_at', { ascending: false }).limit(10000),
    admin.from('attendance_sessions').select('id, church_id, session_date, created_at').gte('session_date', previousDate).limit(50000),
    admin.from('attendance_records').select('status, recorded_at, church_id').gte('recorded_at', currentIso).limit(50000),
    admin.from('app_usage_events').select('user_id, church_id, event_name, platform, app_version, occurred_at').gte('occurred_at', previousIso).limit(50000),
  ]);

  const churches = (churchesResult.data ?? []) as Array<Record<string, unknown>>;
  const profiles = (profilesResult.data ?? []) as Array<Record<string, unknown>>;
  const sessions = (sessionsResult.data ?? []) as Array<Record<string, unknown>>;
  const attendance = (attendanceResult.data ?? []) as Array<Record<string, unknown>>;
  // The dashboard remains usable before the optional analytics migration runs.
  const usage = usageResult.error
    ? []
    : (usageResult.data ?? []) as Array<Record<string, unknown>>;

  const currentSessions = sessions.filter((row) => String(row.session_date) >= currentDate);
  const previousSessions = sessions.filter((row) => {
    const date = String(row.session_date);
    return date >= previousDate && date < currentDate;
  });
  const activeChurchIds = new Set(currentSessions.map((row) => String(row.church_id)));
  const previousChurchIds = new Set(previousSessions.map((row) => String(row.church_id)));
  const retainedChurches = Array.from(previousChurchIds).filter((id) => activeChurchIds.has(id)).length;
  const newProfilesCurrent = profiles.filter((row) => String(row.created_at) >= currentIso).length;
  const newProfilesPrevious = profiles.filter((row) => {
    const date = String(row.created_at);
    return date >= previousIso && date < currentIso;
  }).length;
  const present = attendance.filter((row) => row.status === 'present').length;
  const eligibleAttendance = attendance.filter((row) => row.status !== 'excused').length;
  const attendanceRate = eligibleAttendance ? Math.round((present / eligibleAttendance) * 100) : 0;
  const activeUsers7 = new Set(
    usage
      .filter((row) => String(row.occurred_at) >= new Date(now.getTime() - 7 * DAY).toISOString())
      .map((row) => String(row.user_id)),
  ).size;
  const activeUsers30 = new Set(
    usage.filter((row) => String(row.occurred_at) >= currentIso).map((row) => String(row.user_id)),
  ).size;
  const todayUsage = usage.filter(
    (row) => dateKeyInDashboardTimeZone(String(row.occurred_at)) === todayKey,
  );
  const activeUsersToday = new Set(todayUsage.map((row) => String(row.user_id))).size;
  const appOpensToday = todayUsage.filter((row) => row.event_name === 'app_open').length;
  const signInsToday = todayUsage.filter((row) => row.event_name === 'sign_in').length;
  const newProfilesToday = profiles.filter(
    (row) => dateKeyInDashboardTimeZone(String(row.created_at)) === todayKey,
  ).length;
  const newChurchesToday = churches.filter(
    (row) => dateKeyInDashboardTimeZone(String(row.created_at)) === todayKey,
  ).length;
  const sessionsToday = sessions.filter(
    (row) => String(row.session_date).slice(0, 10) === todayKey,
  ).length;
  const activationRate = churchesTotal ? Math.round((activeChurchIds.size / churchesTotal) * 100) : 0;
  const retentionRate = previousChurchIds.size
    ? Math.round((retainedChurches / previousChurchIds.size) * 100)
    : 0;
  const engagementChange = percentChange(sessionsCurrent, sessionsPrevious);
  const userGrowth = percentChange(newProfilesCurrent, newProfilesPrevious);
  const successScore = Math.max(0, Math.min(100, Math.round(
    activationRate * 0.4 + retentionRate * 0.35 + Math.max(0, Math.min(100, 50 + engagementChange)) * 0.25,
  )));

  const platformCounts = usage.reduce<Record<string, number>>((result, row) => {
    const key = String(row.platform ?? 'unknown');
    result[key] = (result[key] ?? 0) + 1;
    return result;
  }, {});
  const versionCounts = usage.reduce<Record<string, number>>((result, row) => {
    const key = String(row.app_version ?? 'غير معروف');
    result[key] = (result[key] ?? 0) + 1;
    return result;
  }, {});

  const churchRows = churches.slice(0, 8).map((church) => {
    const id = String(church.id);
    return {
      id,
      name: String(church.name_ar),
      users: profiles.filter((profile) => profile.church_id === id && profile.is_active).length,
      sessions30: currentSessions.filter((session) => session.church_id === id).length,
      active: activeChurchIds.has(id),
    };
  });

  return {
    generatedAt: now.toISOString(),
    metrics: {
      churchesTotal, profilesActive, membersActive, meetingsActive,
      sessionsCurrent, pendingInvitations, pendingFollowUps, attendanceRate,
      activeUsers7, activeUsers30, activationRate, retentionRate,
      activeUsersToday, appOpensToday, signInsToday, newProfilesToday,
      newChurchesToday, sessionsToday, engagementChange, userGrowth, successScore,
    },
    sessionTrend: dayBuckets(currentSessions, 'session_date'),
    userTrend: dayBuckets(profiles.filter((row) => String(row.created_at) >= currentIso), 'created_at'),
    churchRows,
    platformCounts,
    versionCounts,
    analyticsReady: !usageResult.error,
  };
}

export type DashboardFilters = { days: 7 | 30 | 90; churchId?: string };
export type AdminFormOption = { value: string; label: string };

function safeRows(result: { data: unknown; error?: unknown }) {
  return Array.isArray(result.data) ? result.data as Array<Record<string, unknown>> : [];
}

type MeetingGroup = {
  id: string;
  church: string;
  meeting: string;
  servants: string[];
  members: string[];
  memberCount: number;
};

function buildMeetingGroups({
  churches,
  profiles,
  meetings,
  classes,
  members,
  memberMeetingAssignments,
  meetingAssignments,
}: {
  churches: Array<Record<string, unknown>>;
  profiles: Array<Record<string, unknown>>;
  meetings: Array<Record<string, unknown>>;
  classes: Array<Record<string, unknown>>;
  members: Array<Record<string, unknown>>;
  memberMeetingAssignments: Array<Record<string, unknown>>;
  meetingAssignments: Array<Record<string, unknown>>;
}): MeetingGroup[] {
  const churchNames = new Map(churches.map((church) => [String(church.id), String(church.name_ar || church.name || 'كنيسة بلا اسم')]));
  const meetingNames = new Map(meetings.map((meeting) => [String(meeting.id), String(meeting.name_ar || meeting.name || 'اجتماع بلا اسم')]));
  const activeMembers = members.filter((member) => member.is_active);
  const activeMemberById = new Map(activeMembers.map((member) => [String(member.id), member]));
  const meetingChurchById = new Map(meetings.map((meeting) => [String(meeting.id), String(meeting.church_id)]));
  const meetingMemberIds = new Map<string, Set<string>>();
  const addMeetingMember = (meetingId: string, memberId: string) => {
    const ids = meetingMemberIds.get(meetingId) ?? new Set<string>();
    ids.add(memberId);
    meetingMemberIds.set(meetingId, ids);
  };
  const membersWithAssignments = new Set<string>();
  for (const assignment of memberMeetingAssignments) {
    const memberId = String(assignment.member_id);
    const meetingId = String(assignment.meeting_id);
    const member = activeMemberById.get(memberId);
    if (member && String(member.church_id) === String(assignment.church_id)
      && meetingChurchById.get(meetingId) === String(assignment.church_id)) {
      membersWithAssignments.add(memberId);
      addMeetingMember(meetingId, memberId);
    }
  }
  const classMeetingIds = new Map(classes.map((schoolClass) => [String(schoolClass.id), String(schoolClass.meeting_id)]));
  for (const member of activeMembers) {
    const memberId = String(member.id);
    if (membersWithAssignments.has(memberId)) continue;
    const meetingId = String(member.meeting_id || classMeetingIds.get(String(member.sunday_school_class_id)) || '');
    if (meetingId && meetingChurchById.get(meetingId) === String(member.church_id)) addMeetingMember(meetingId, memberId);
  }
  const servantsByMeeting = new Map<string, string[]>();
  const profilesById = new Map(profiles.map((profile) => [String(profile.id), profile]));
  for (const assignment of meetingAssignments) {
    const profile = profilesById.get(String(assignment.user_id));
    if (!profile?.is_active) continue;
    const meetingKey = `${assignment.church_id}:${assignment.meeting_id}`;
    const names = servantsByMeeting.get(meetingKey) ?? [];
    const name = String(profile.full_name || profile.email || 'خادم بلا اسم');
    if (!names.includes(name)) names.push(name);
    servantsByMeeting.set(meetingKey, names);
  }
  return meetings.map((meeting) => {
    const meetingId = String(meeting.id);
    const meetingKey = `${meeting.church_id}:${meetingId}`;
    const memberNames = Array.from(meetingMemberIds.get(meetingId) ?? [])
      .map((memberId) => activeMemberById.get(memberId))
      .filter((member): member is Record<string, unknown> => Boolean(member))
      .map((member) => String(member.full_name || 'مخدوم بلا اسم'))
      .sort((a, b) => a.localeCompare(b, 'ar'));
    return {
      id: meetingId,
      church: churchNames.get(String(meeting.church_id)) ?? 'كنيسة بلا اسم',
      meeting: meetingNames.get(meetingId) ?? 'اجتماع بلا اسم',
      servants: (servantsByMeeting.get(meetingKey) ?? []).sort((a, b) => a.localeCompare(b, 'ar')),
      members: memberNames,
      memberCount: memberNames.length,
    };
  }).sort((a, b) => b.memberCount - a.memberCount
    || a.church.localeCompare(b.church, 'ar')
    || a.meeting.localeCompare(b.meeting, 'ar'));
}

export async function getMeetingGroupsData(churchId?: string) {
  const admin = createSupabaseAdminClient();
  const [churchesResult, profilesResult, meetingsResult, classesResult, membersResult, memberAssignmentsResult, meetingAssignmentsResult] = await Promise.all([
    admin.from('churches').select('id, name_ar, name').order('name_ar').limit(5000),
    admin.from('profiles').select('id, church_id, full_name, email, is_active').limit(20000),
    admin.from('meetings').select('id, church_id, name_ar, name').limit(20000),
    admin.from('sunday_school_classes').select('id, church_id, meeting_id, name_ar, name').limit(20000),
    admin.from('members').select('id, church_id, meeting_id, sunday_school_class_id, full_name, is_active').limit(50000),
    admin.from('member_meeting_assignments').select('church_id, member_id, meeting_id').limit(100000),
    admin.from('meeting_assignments').select('church_id, meeting_id, user_id').limit(50000),
  ]);
  const requiredErrors = [churchesResult, profilesResult, meetingsResult, classesResult, membersResult, meetingAssignmentsResult].filter((result) => result.error);
  if (requiredErrors.length) throw new Error('تعذر تحميل مجموعات الاجتماعات من قاعدة البيانات.');
  const churches = safeRows(churchesResult);
  const scope = (rows: Array<Record<string, unknown>>) => churchId ? rows.filter((row) => String(row.church_id) === churchId) : rows;
  const groups = buildMeetingGroups({
    churches,
    profiles: scope(safeRows(profilesResult)),
    meetings: scope(safeRows(meetingsResult)),
    classes: scope(safeRows(classesResult)),
    members: scope(safeRows(membersResult)),
    memberMeetingAssignments: scope(safeRows(memberAssignmentsResult)),
    meetingAssignments: scope(safeRows(meetingAssignmentsResult)),
  });
  return { churches, groups };
}

/** Detailed owner metrics. All filtering is server-side and only uses the service-role client. */
export async function getEnhancedDashboardData(filters: DashboardFilters) {
  const admin = createSupabaseAdminClient();
  const now = new Date();
  const start = new Date(now.getTime() - filters.days * DAY);
  const previousStart = new Date(now.getTime() - filters.days * 2 * DAY);
  const startDate = isoDate(start);
  const previousDate = isoDate(previousStart);
  const scoped = (rows: Array<Record<string, unknown>>) => filters.churchId
    ? rows.filter((row) => String(row.church_id) === filters.churchId)
    : rows;
  const [churchesResult, profilesResult, meetingsResult, classesResult, membersResult, sessionsResult, recordsResult, invitationsResult, followUpsResult, supportResult, usageResult, classAssignmentsResult, meetingAssignmentsResult, auditResult] = await Promise.all([
    admin.from('churches').select('id, name_ar, name').order('name_ar').limit(5000),
    admin.from('profiles').select('id, church_id, full_name, email, role, is_active, created_at').limit(20000),
    admin.from('meetings').select('id, church_id, name_ar, name, is_active').limit(20000),
    admin.from('sunday_school_classes').select('id, church_id, meeting_id, name_ar, name, is_active').limit(20000),
    admin.from('members').select('id, church_id, meeting_id, sunday_school_class_id, full_name, code, is_active, created_at, joined_on').limit(50000),
    admin.from('attendance_sessions').select('id, church_id, meeting_id, session_date, title').gte('session_date', previousDate).limit(50000),
    admin.from('attendance_records').select('session_id, member_id, church_id, status, recorded_at').gte('recorded_at', previousStart.toISOString()).limit(100000),
    admin.from('invitations').select('id, church_id, full_name, email, is_used, declined_at, created_at').gte('created_at', previousStart.toISOString()).limit(50000),
    admin.from('follow_ups').select('id, church_id, member_id, contact_status, follow_up_date').limit(50000),
    admin.from('support_tickets').select('id, church_id, category, status, created_at, updated_at').limit(50000),
    admin.from('app_usage_events').select('church_id, occurred_at').gte('occurred_at', previousStart.toISOString()).limit(100000),
    admin.from('class_assignments').select('church_id, class_id, user_id, can_take_attendance, can_view_reports').limit(50000),
    admin.from('meeting_assignments').select('church_id, meeting_id, user_id, can_take_attendance, can_view_reports').limit(50000),
    admin.from('admin_audit_logs').select('admin_user_id, action, table_name, created_at').order('created_at', { ascending: false }).limit(20),
  ]);
  const churches = safeRows(churchesResult);
  const profiles = scoped(safeRows(profilesResult));
  const meetings = scoped(safeRows(meetingsResult));
  const classes = scoped(safeRows(classesResult));
  const members = scoped(safeRows(membersResult));
  const sessions = scoped(safeRows(sessionsResult));
  const records = scoped(safeRows(recordsResult));
  const invitations = scoped(safeRows(invitationsResult));
  const followUps = scoped(safeRows(followUpsResult));
  const support = scoped(safeRows(supportResult));
  const usage = scoped(safeRows(usageResult));
  const classAssignments = scoped(safeRows(classAssignmentsResult));
  const meetingAssignments = scoped(safeRows(meetingAssignmentsResult));
  const auditLogs = safeRows(auditResult);
  const selectedChurches = filters.churchId
    ? churches.filter((church) => String(church.id) === filters.churchId)
    : churches;
  const inCurrent = (value: unknown) => String(value).slice(0, 10) >= startDate;
  const inPrevious = (value: unknown) => {
    const date = String(value).slice(0, 10);
    return date >= previousDate && date < startDate;
  };
  const sessionById = new Map(sessions.map((row) => [String(row.id), row]));
  const currentSessions = sessions.filter((row) => inCurrent(row.session_date));
  const previousSessions = sessions.filter((row) => inPrevious(row.session_date));
  const currentSessionIds = new Set(currentSessions.map((row) => String(row.id)));
  const previousSessionIds = new Set(previousSessions.map((row) => String(row.id)));
  const currentRecords = records.filter((row) => currentSessionIds.has(String(row.session_id)));
  const previousRecords = records.filter((row) => previousSessionIds.has(String(row.session_id)));
  const currentMembers = members.filter((row) => inCurrent(row.joined_on || row.created_at));
  const activeMembersTotal = members.filter((row) => row.is_active).length;
  const currentInvitations = invitations.filter((row) => inCurrent(row.created_at));
  const activeChurches = selectedChurches.filter((church) => {
    const id = String(church.id);
    return members.some((row) => String(row.church_id) === id && row.is_active)
      && meetings.some((row) => String(row.church_id) === id && row.is_active)
      && currentRecords.some((row) => String(row.church_id) === id);
  });
  const nameForChurch = (id: string) => {
    const church = churches.find((row) => String(row.id) === id);
    return String(church?.name_ar || church?.name || 'كنيسة بلا اسم');
  };
  const nameForMember = (id: string) => {
    const member = members.find((row) => String(row.id) === id);
    return String(member?.full_name || 'مخدوم غير معروف');
  };
  const nameForMeeting = (id: string) => {
    const meeting = meetings.find((row) => String(row.id) === id);
    return String(meeting?.name_ar || meeting?.name || 'اجتماع غير معروف');
  };
  const nameForClass = (id: string) => {
    const schoolClass = classes.find((row) => String(row.id) === id);
    return String(schoolClass?.name_ar || schoolClass?.name || 'فصل غير معروف');
  };
  const churchActivity = churches
    .filter((church) => !filters.churchId || String(church.id) === filters.churchId)
    .map((church) => {
      const id = String(church.id);
      const usageDates = usage.filter((row) => String(row.church_id) === id).map((row) => String(row.occurred_at));
      const sessionDates = sessions.filter((row) => String(row.church_id) === id).map((row) => String(row.session_date));
      const lastActivity = [...usageDates, ...sessionDates].sort().at(-1) ?? null;
      const attendance = currentRecords.filter((row) => String(row.church_id) === id).length;
      return { id, name: nameForChurch(id), attendance, sessions: currentSessions.filter((row) => String(row.church_id) === id).length, lastActivity };
    })
    .sort((a, b) => b.attendance - a.attendance || b.sessions - a.sessions);
  const meetingPerformance = meetings.map((meeting) => {
    const id = String(meeting.id);
    const current = currentRecords.filter((row) => String(sessionById.get(String(row.session_id))?.meeting_id) === id);
    const previous = previousRecords.filter((row) => String(sessionById.get(String(row.session_id))?.meeting_id) === id);
    const present = current.filter((row) => row.status === 'present').length;
    const absent = current.filter((row) => row.status === 'absent').length;
    return { id, name: nameForMeeting(id), church: nameForChurch(String(meeting.church_id)), newMembers: currentMembers.filter((row) => String(row.meeting_id) === id).length, present, absent, change: percentChange(present, previous.filter((row) => row.status === 'present').length) };
  }).sort((a, b) => b.present - a.present);
  const absenceCounts = currentRecords.filter((row) => row.status === 'absent').reduce<Map<string, number>>((map, row) => {
    const id = String(row.member_id); map.set(id, (map.get(id) ?? 0) + 1); return map;
  }, new Map());
  const repeatedAbsences = Array.from(absenceCounts.entries()).filter(([, count]) => count >= 2).map(([id, count]) => ({ name: nameForMember(id), count })).sort((a, b) => b.count - a.count).slice(0, 5);
  const inactiveProfiles = profiles.filter((row) => !row.is_active).slice(0, 5).map((row) => ({ name: String(row.full_name || row.email || 'مستخدم بلا اسم'), church: nameForChurch(String(row.church_id)) }));
  const pendingInvitations = invitations.filter((row) => !row.is_used && !row.declined_at).slice(0, 5).map((row) => ({ name: String(row.full_name || row.email || 'دعوة بلا اسم'), church: nameForChurch(String(row.church_id)) }));
  const unresolvedFollowUps = followUps.filter((row) => ['pending', 'contacted', 'no_response'].includes(String(row.contact_status))).length;
  const openSupport = support.filter((row) => ['open', 'in_progress'].includes(String(row.status)));
  const resolvedSupport = support.filter((row) => ['resolved', 'closed'].includes(String(row.status)) && inCurrent(row.updated_at));
  const avgResolutionHours = resolvedSupport.length ? Math.round(resolvedSupport.reduce((sum, row) => sum + (new Date(String(row.updated_at)).getTime() - new Date(String(row.created_at)).getTime()) / 3_600_000, 0) / resolvedSupport.length) : null;
  const categoryCounts = support.reduce<Record<string, number>>((result, row) => { const key = String(row.category || 'other'); result[key] = (result[key] ?? 0) + 1; return result; }, {});
  const topCategory = Object.entries(categoryCounts).sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  const invitationStats = {
    sent: currentInvitations.length,
    accepted: currentInvitations.filter((row) => row.is_used).length,
    pending: currentInvitations.filter((row) => !row.is_used && !row.declined_at).length,
    declined: currentInvitations.filter((row) => Boolean(row.declined_at)).length,
  };
  const activeServants = profiles.filter((profile) => profile.is_active && (classAssignments.some((row) => String(row.user_id) === String(profile.id)) || meetingAssignments.some((row) => String(row.user_id) === String(profile.id))));
  const previousPresent = previousRecords.filter((row) => row.status === 'present').length;
  const monthlyGoals = [
    { label: 'كنائس نشطة', current: activeChurches.length, target: selectedChurches.length },
    { label: 'حضور', current: currentRecords.filter((row) => row.status === 'present').length, target: Math.max(1, previousPresent) },
    { label: 'خدام نشطون', current: activeServants.length, target: Math.max(1, profiles.filter((row) => row.is_active).length) },
    { label: 'دعوات مقبولة', current: invitationStats.accepted, target: Math.max(1, invitationStats.sent) },
  ].map((goal) => ({ ...goal, progress: Math.min(100, Math.round(goal.current / goal.target * 100)) }));
  const isChurchRecentlyActive = (churchId: string, windowDays: number) => {
    const limit = new Date(now.getTime() - windowDays * DAY).toISOString();
    return usage.some((row) => String(row.church_id) === churchId && String(row.occurred_at) >= limit)
      || sessions.some((row) => String(row.church_id) === churchId && String(row.session_date) >= isoDate(new Date(now.getTime() - windowDays * DAY)));
  };
  const retention = [7, 30].map((windowDays) => ({ days: windowDays, active: selectedChurches.filter((church) => isChurchRecentlyActive(String(church.id), windowDays)).length, total: selectedChurches.length }));
  const healthScores = selectedChurches.map((church) => {
    const id = String(church.id); const hasAttendance = currentRecords.some((row) => String(row.church_id) === id); const hasServant = activeServants.some((profile) => String(profile.church_id) === id); const recentlyUsed = isChurchRecentlyActive(id, 14); const recentlyUpdated = currentMembers.some((member) => String(member.church_id) === id) || currentSessions.some((session) => String(session.church_id) === id);
    const score = [hasAttendance, hasServant, recentlyUsed, recentlyUpdated].filter(Boolean).length * 25;
    return { id, name: nameForChurch(id), score };
  }).sort((a, b) => a.score - b.score);
  const noAssignmentServants = profiles.filter((profile) => profile.is_active && !activeServants.some((servant) => String(servant.id) === String(profile.id))).map((profile) => String(profile.full_name || profile.email || 'خادم بلا اسم'));
  const smartAlerts = [
    ...selectedChurches.filter((church) => !isChurchRecentlyActive(String(church.id), 14)).map((church) => ({ kind: 'كنيسة بلا حضور 14 يومًا', name: nameForChurch(String(church.id)) })),
    ...meetingPerformance.filter((meeting) => meeting.change <= -20).map((meeting) => ({ kind: 'هبوط ملحوظ في الحضور', name: meeting.name })),
    ...noAssignmentServants.map((name) => ({ kind: 'خادم بلا تكليف', name })),
  ].slice(0, 12);
  const atRisk = [...healthScores.filter((church) => church.score < 50).map((church) => ({ type: 'كنيسة', name: church.name, reason: `Health score ${church.score}%` })), ...meetingPerformance.filter((meeting) => meeting.change <= -20).map((meeting) => ({ type: 'اجتماع', name: meeting.name, reason: `انخفاض ${Math.abs(meeting.change)}%` }))].slice(0, 8);
  const roleName = (role: unknown) => ({ super_admin: 'مدير النظام', church_admin: 'مدير الكنيسة', attendance_officer: 'خادم حضور', reports_viewer: 'مشاهد تقارير' } as Record<string, string>)[String(role)] ?? 'خادم';
  const servantPermissions = profiles.filter((profile) => profile.is_active).map((profile) => {
    const id = String(profile.id);
    const assignments = [
      ...meetingAssignments.filter((row) => String(row.user_id) === id).map((row) => ({ target: `اجتماع: ${nameForMeeting(String(row.meeting_id))}`, attendance: Boolean(row.can_take_attendance), reports: Boolean(row.can_view_reports) })),
      ...classAssignments.filter((row) => String(row.user_id) === id).map((row) => ({ target: `فصل: ${nameForClass(String(row.class_id))}`, attendance: Boolean(row.can_take_attendance), reports: Boolean(row.can_view_reports) })),
    ];
    return { id, name: String(profile.full_name || profile.email || 'خادم بلا اسم'), church: nameForChurch(String(profile.church_id)), role: roleName(profile.role), assignments };
  }).sort((a, b) => a.church.localeCompare(b.church, 'ar') || a.name.localeCompare(b.name, 'ar'));
  const attendanceTrend = Array.from({ length: Math.min(filters.days, 30) }, (_, index) => {
    const date = isoDate(new Date(now.getTime() - (Math.min(filters.days, 30) - index - 1) * DAY));
    const ids = new Set(currentSessions.filter((session) => String(session.session_date) === date).map((session) => String(session.id)));
    return { date, count: currentRecords.filter((record) => ids.has(String(record.session_id)) && record.status === 'present').length };
  });
  const recentChanges = auditLogs.map((log) => ({ actor: String(profiles.find((profile) => String(profile.id) === String(log.admin_user_id))?.full_name || 'مدير النظام'), action: String(log.action), table: String(log.table_name), at: String(log.created_at) }));
  return {
    generatedAt: now.toISOString(), churches, filters, supportReady: !supportResult.error, analyticsReady: !usageResult.error,
    summary: { activeChurchRate: selectedChurches.length ? Math.round((activeChurches.length / selectedChurches.length) * 100) : 0, activeChurches: activeChurches.length, activeMembersTotal, currentMembers: currentMembers.length, present: currentRecords.filter((row) => row.status === 'present').length, absent: currentRecords.filter((row) => row.status === 'absent').length, unresolvedFollowUps, openSupport: openSupport.length, avgResolutionHours, topCategory, invitationStats },
    churchActivity, meetingPerformance, repeatedAbsences, inactiveProfiles, pendingInvitations, servantPermissions, attendanceTrend, recentChanges, monthlyGoals, smartAlerts, healthScores, atRisk, retention,
  };
}

export async function getAdminFormOptions(fields: string[]): Promise<Record<string, AdminFormOption[]>> {
  const admin = createSupabaseAdminClient();
  const needed = new Set(fields);
  const needsProfiles = ['user_id', 'responsible_user_id', 'created_by', 'assigned_by', 'recorded_by'].some((field) => needed.has(field));
  const [churches, profiles, meetings, classes, members, sessions] = await Promise.all([
    needed.has('church_id') ? admin.from('churches').select('id, name_ar, name').order('name_ar').limit(2000) : Promise.resolve({ data: [] }),
    needsProfiles ? admin.from('profiles').select('id, full_name, email').order('full_name').limit(2000) : Promise.resolve({ data: [] }),
    needed.has('meeting_id') ? admin.from('meetings').select('id, name_ar, name').order('name_ar').limit(2000) : Promise.resolve({ data: [] }),
    needed.has('class_id') || needed.has('sunday_school_class_id') ? admin.from('sunday_school_classes').select('id, name_ar, name').order('name_ar').limit(2000) : Promise.resolve({ data: [] }),
    needed.has('member_id') ? admin.from('members').select('id, full_name, code').order('full_name').limit(5000) : Promise.resolve({ data: [] }),
    needed.has('session_id') ? admin.from('attendance_sessions').select('id, title, session_date').order('session_date', { ascending: false }).limit(2000) : Promise.resolve({ data: [] }),
  ]);
  const options = (rows: Array<Record<string, unknown>>, label: (row: Record<string, unknown>) => string) => rows.map((row) => ({ value: String(row.id), label: label(row) }));
  const churchOptions = options(safeRows(churches), (row) => String(row.name_ar || row.name || 'كنيسة بلا اسم'));
  const profileOptions = options(safeRows(profiles), (row) => String(row.full_name || row.email || 'مستخدم بلا اسم'));
  const meetingOptions = options(safeRows(meetings), (row) => String(row.name_ar || row.name || 'اجتماع بلا اسم'));
  const classOptions = options(safeRows(classes), (row) => String(row.name_ar || row.name || 'فصل بلا اسم'));
  const memberOptions = options(safeRows(members), (row) => `${row.full_name || 'مخدوم بلا اسم'}${row.code ? ` (${row.code})` : ''}`);
  const sessionOptions = options(safeRows(sessions), (row) => String(row.title || row.session_date || 'جلسة حضور'));
  return {
    church_id: churchOptions, meeting_id: meetingOptions, class_id: classOptions, sunday_school_class_id: classOptions,
    member_id: memberOptions, session_id: sessionOptions, user_id: profileOptions, responsible_user_id: profileOptions,
    created_by: profileOptions, assigned_by: profileOptions, recorded_by: profileOptions,
  };
}

export async function getTableRows(
  tableKey: AdminTableKey,
  queryText: string,
  page: number,
) {
  const admin = createSupabaseAdminClient();
  const config: AdminTableConfig = adminTables[tableKey];
  const pageSize = 25;
  const from = Math.max(0, page - 1) * pageSize;
  const to = from + pageSize - 1;
  let query = admin
    .from(config.table)
    .select('*', { count: 'exact' })
    .order(config.orderBy, { ascending: false })
    .range(from, to);

  const safeQuery = queryText.trim().replace(/[,%()]/g, ' ');
  if (safeQuery && config.searchableColumns.length) {
    query = query.or(
      config.searchableColumns.map((column) => `${column}.ilike.%${safeQuery}%`).join(','),
    );
  }

  const { data, count, error } = await query;
  if (error) throw error;

  const rows = (data ?? []) as Array<Record<string, unknown>>;
  const idsFor = (column: string) => Array.from(new Set(
    rows
      .map((row) => row[column])
      .filter((value): value is string => typeof value === 'string' && value.length > 0),
  ));
  const churchIds = idsFor('church_id');
  const profileIds = Array.from(new Set([
    ...idsFor('user_id'),
    ...idsFor('responsible_user_id'),
    ...idsFor('created_by'),
    ...idsFor('assigned_by'),
    ...idsFor('recorded_by'),
    ...idsFor('admin_user_id'),
  ]));
  const meetingIds = idsFor('meeting_id');
  const classIds = idsFor('class_id');
  const memberIds = idsFor('member_id');
  const sessionIds = idsFor('session_id');
  const auditReferenceDefinitions: Record<string, { label: string; fields: string }> = {
    churches: { label: 'كنيسة', fields: 'id, name_ar, name' },
    profiles: { label: 'مستخدم', fields: 'id, full_name, email' },
    meetings: { label: 'اجتماع', fields: 'id, name_ar, name' },
    sunday_school_classes: { label: 'فصل', fields: 'id, name_ar, name' },
    members: { label: 'مخدوم', fields: 'id, full_name, code' },
    attendance_sessions: { label: 'جلسة حضور', fields: 'id, title, session_date' },
    invitations: { label: 'دعوة', fields: 'id, full_name, email' },
    follow_ups: { label: 'متابعة', fields: 'id, reason, follow_up_date' },
  };
  const auditIdsByTable = rows.reduce<Record<string, string[]>>((result, row) => {
    const tableName = String(row.table_name ?? '');
    const rowId = row.row_id;
    if (auditReferenceDefinitions[tableName] && typeof rowId === 'string' && rowId) {
      result[tableName] = Array.from(new Set([...(result[tableName] ?? []), rowId]));
    }
    return result;
  }, {});

  const [churches, profiles, meetings, classes, members, sessions] = await Promise.all([
    churchIds.length ? admin.from('churches').select('id, name_ar, name').in('id', churchIds) : Promise.resolve({ data: [] }),
    profileIds.length ? admin.from('profiles').select('id, full_name, email').in('id', profileIds) : Promise.resolve({ data: [] }),
    meetingIds.length ? admin.from('meetings').select('id, name_ar, name').in('id', meetingIds) : Promise.resolve({ data: [] }),
    classIds.length ? admin.from('sunday_school_classes').select('id, name_ar, name').in('id', classIds) : Promise.resolve({ data: [] }),
    memberIds.length ? admin.from('members').select('id, full_name, code').in('id', memberIds) : Promise.resolve({ data: [] }),
    sessionIds.length ? admin.from('attendance_sessions').select('id, title, session_date').in('id', sessionIds) : Promise.resolve({ data: [] }),
  ]);
  const auditReferences = await Promise.all(Object.entries(auditIdsByTable).map(async ([tableName, ids]) => {
    const definition = auditReferenceDefinitions[tableName];
    const { data, error: auditError } = await admin.from(tableName).select(definition.fields).in('id', ids);
    if (auditError) throw auditError;
    return { tableName, label: definition.label, rows: (data ?? []) as unknown as Array<Record<string, unknown>> };
  }));

  const names = (result: { data: Array<Record<string, unknown>> | null }, label: (row: Record<string, unknown>) => string) =>
    new Map((result.data ?? []).map((row) => [String(row.id), label(row)]));
  const churchNames = names(churches, (row) => String(row.name_ar || row.name || 'كنيسة بلا اسم'));
  const profileNames = names(profiles, (row) => String(row.full_name || row.email || 'مستخدم بلا اسم'));
  const meetingNames = names(meetings, (row) => String(row.name_ar || row.name || 'اجتماع بلا اسم'));
  const classNames = names(classes, (row) => String(row.name_ar || row.name || 'فصل بلا اسم'));
  const memberNames = names(members, (row) => {
    const name = String(row.full_name || 'مخدوم بلا اسم');
    return row.code ? `${name} (${row.code})` : name;
  });
  const sessionNames = names(sessions, (row) => String(row.title || row.session_date || 'جلسة حضور'));
  const auditRowNames = new Map(auditReferences.flatMap(({ tableName, label, rows: auditRows }) =>
    auditRows.map((row) => {
      const name = String(row.name_ar || row.name || row.full_name || row.title || row.reason || row.email || row.session_date || 'سجل');
      return [`${tableName}:${row.id}`, `${label}: ${name}`] as const;
    }),
  ));
  const displayRows: Array<Record<string, unknown>> = rows.map((row) => ({
    ...row,
    ...(churchNames.has(String(row.church_id)) ? { church_id: churchNames.get(String(row.church_id)) } : {}),
    ...(profileNames.has(String(row.user_id)) ? { user_id: profileNames.get(String(row.user_id)) } : {}),
    ...(profileNames.has(String(row.admin_user_id)) ? { admin_user_id: profileNames.get(String(row.admin_user_id)) } : {}),
    ...(profileNames.has(String(row.responsible_user_id)) ? { responsible_user_id: profileNames.get(String(row.responsible_user_id)) } : {}),
    ...(meetingNames.has(String(row.meeting_id)) ? { meeting_id: meetingNames.get(String(row.meeting_id)) } : {}),
    ...(classNames.has(String(row.class_id)) ? { class_id: classNames.get(String(row.class_id)) } : {}),
    ...(memberNames.has(String(row.member_id)) ? { member_id: memberNames.get(String(row.member_id)) } : {}),
    ...(sessionNames.has(String(row.session_id)) ? { session_id: sessionNames.get(String(row.session_id)) } : {}),
    ...(auditRowNames.has(`${row.table_name}:${row.row_id}`) ? { row_id: auditRowNames.get(`${row.table_name}:${row.row_id}`) } : {}),
  }));

  return {
    rows,
    displayRows,
    count: count ?? 0,
    page,
    pageSize,
    pages: Math.max(1, Math.ceil((count ?? 0) / pageSize)),
  };
}
