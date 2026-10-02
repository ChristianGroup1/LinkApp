import { NextRequest } from 'next/server';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { adminTables, isAdminTable } from '@/lib/admin/schema';
import { adminColumnLabels, formatAdminCell } from '@/lib/admin/labels';

function csvCell(value: unknown) {
  let text = value === null || value === undefined ? '' : String(value);
  // Excel and other spreadsheet apps may evaluate untrusted text as a formula.
  if (/^[\s\u0000-\u001f]*[=+@-]/.test(text)) text = `'${text}`;
  return `"${text.replaceAll('"', '""')}"`;
}

type RangeQuery = {
  range: (from: number, to: number) => PromiseLike<{
    data: unknown[] | null;
    error: { message: string } | null;
  }>;
};

async function readAllRows(query: RangeQuery) {
  const rows: unknown[] = [];
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await query.range(from, from + pageSize - 1);
    if (error) return { data: rows, error };
    rows.push(...(data ?? []));
    if (!data || data.length < pageSize) return { data: rows, error: null };
  }
}

export async function GET(request: NextRequest) {
  await requireSuperAdmin();
  const backupChurchId = request.nextUrl.searchParams.get('churchId');
  if (request.nextUrl.searchParams.get('backup') === 'church' && backupChurchId) {
    const admin = createSupabaseAdminClient();
    const [church, profiles, meetings, classes, members, memberMeetings, classAssignments, meetingAssignments, sessions, records, followUps, invitations, tickets, usage] = await Promise.all([
      admin.from('churches').select('*').eq('id', backupChurchId).maybeSingle(),
      readAllRows(admin.from('profiles').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('meetings').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('sunday_school_classes').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('members').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('member_meeting_assignments').select('*').eq('church_id', backupChurchId).order('member_id').order('meeting_id')),
      readAllRows(admin.from('class_assignments').select('*').eq('church_id', backupChurchId).order('user_id').order('class_id')),
      readAllRows(admin.from('meeting_assignments').select('*').eq('church_id', backupChurchId).order('user_id').order('meeting_id')),
      readAllRows(admin.from('attendance_sessions').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('attendance_records').select('*').eq('church_id', backupChurchId).order('session_id').order('member_id')),
      readAllRows(admin.from('follow_ups').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('invitations').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('support_tickets').select('*').eq('church_id', backupChurchId).order('id')),
      readAllRows(admin.from('app_usage_events').select('*').eq('church_id', backupChurchId).order('occurred_at')),
    ]);
    const failedQuery = [church, profiles, meetings, classes, members, memberMeetings, classAssignments, meetingAssignments, sessions, records, followUps, invitations, tickets].find((result) => result.error);
    if (failedQuery?.error) return new Response('تعذر إنشاء نسخة كاملة من بيانات الكنيسة. لم يتم تنزيل نسخة احتياطية.', { status: 500 });
    if (!church.data) return new Response('Not found', { status: 404 });
    const ticketIds = (tickets.data as Array<{ id: string }> | null ?? []).map((ticket) => ticket.id);
    const messages = ticketIds.length
      ? await readAllRows(admin.from('support_ticket_messages').select('*').in('ticket_id', ticketIds).order('ticket_id').order('created_at'))
      : { data: [], error: null };
    if (messages.error) return new Response('تعذر إنشاء نسخة كاملة من محادثات البلاغات. لم يتم تنزيل نسخة احتياطية.', { status: 500 });
    const profileIds = (profiles.data as Array<{ id: string }> | null ?? []).map((profile) => profile.id);
    const auditLogs = profileIds.length
      ? await readAllRows(admin.from('admin_audit_logs').select('*').in('admin_user_id', profileIds).order('created_at'))
      : { data: [], error: null };
    const optionalTablesUnavailable = [
      ...(usage.error ? ['app_usage_events'] : []),
      ...(auditLogs.error ? ['admin_audit_logs'] : []),
    ];
    const backup = { exported_at: new Date().toISOString(), optional_tables_unavailable: optionalTablesUnavailable, church: church.data, profiles: profiles.data ?? [], meetings: meetings.data ?? [], classes: classes.data ?? [], members: members.data ?? [], member_meeting_assignments: memberMeetings.data ?? [], class_assignments: classAssignments.data ?? [], meeting_assignments: meetingAssignments.data ?? [], attendance_sessions: sessions.data ?? [], attendance_records: records.data ?? [], follow_ups: followUps.data ?? [], invitations: invitations.data ?? [], support_tickets: tickets.data ?? [], support_ticket_messages: messages.data ?? [], app_usage_events: usage.data ?? [], admin_audit_logs: auditLogs.data ?? [] };
    return new Response(JSON.stringify(backup, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8', 'Content-Disposition': `attachment; filename="link-church-backup-${backupChurchId}.json"` } });
  }
  const tableKey = request.nextUrl.searchParams.get('table') ?? '';
  if (!isAdminTable(tableKey)) return new Response('Not found', { status: 404 });
  const config = adminTables[tableKey];
  const { data, error } = await readAllRows(createSupabaseAdminClient().from(config.table).select(config.visibleColumns.join(',')).order(config.orderBy, { ascending: false }));
  if (error) return new Response('Export failed', { status: 500 });
  const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
  const csv = `\uFEFF${config.visibleColumns.map((column) => csvCell(adminColumnLabels[column] ?? column)).join(',')}\n${rows.map((row) => config.visibleColumns.map((column) => csvCell(formatAdminCell(column, row[column]))).join(',')).join('\n')}`;
  return new Response(csv, { headers: { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': `attachment; filename="link-${tableKey}.csv"` } });
}
