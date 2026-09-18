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

  return {
    rows: (data ?? []) as Array<Record<string, unknown>>,
    count: count ?? 0,
    page,
    pageSize,
    pages: Math.max(1, Math.ceil((count ?? 0) / pageSize)),
  };
}
