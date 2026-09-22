import { NextRequest } from 'next/server';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { adminTables, isAdminTable } from '@/lib/admin/schema';

function csvCell(value: unknown) { const text = value === null || value === undefined ? '' : String(value); return `"${text.replaceAll('"', '""')}"`; }

export async function GET(request: NextRequest) {
  await requireSuperAdmin();
  const backupChurchId = request.nextUrl.searchParams.get('churchId');
  if (request.nextUrl.searchParams.get('backup') === 'church' && backupChurchId) {
    const admin = createSupabaseAdminClient();
    const [church, profiles, meetings, classes, members, sessions, records, followUps, invitations, tickets, usage] = await Promise.all([
      admin.from('churches').select('*').eq('id', backupChurchId).maybeSingle(),
      admin.from('profiles').select('*').eq('church_id', backupChurchId), admin.from('meetings').select('*').eq('church_id', backupChurchId),
      admin.from('sunday_school_classes').select('*').eq('church_id', backupChurchId), admin.from('members').select('*').eq('church_id', backupChurchId),
      admin.from('attendance_sessions').select('*').eq('church_id', backupChurchId), admin.from('attendance_records').select('*').eq('church_id', backupChurchId),
      admin.from('follow_ups').select('*').eq('church_id', backupChurchId), admin.from('invitations').select('*').eq('church_id', backupChurchId),
      admin.from('support_tickets').select('*').eq('church_id', backupChurchId), admin.from('app_usage_events').select('*').eq('church_id', backupChurchId),
    ]);
    if (!church.data) return new Response('Not found', { status: 404 });
    const backup = { exported_at: new Date().toISOString(), church: church.data, profiles: profiles.data ?? [], meetings: meetings.data ?? [], classes: classes.data ?? [], members: members.data ?? [], attendance_sessions: sessions.data ?? [], attendance_records: records.data ?? [], follow_ups: followUps.data ?? [], invitations: invitations.data ?? [], support_tickets: tickets.data ?? [], app_usage_events: usage.data ?? [] };
    return new Response(JSON.stringify(backup, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8', 'Content-Disposition': `attachment; filename="link-church-backup-${backupChurchId}.json"` } });
  }
  const tableKey = request.nextUrl.searchParams.get('table') ?? '';
  if (!isAdminTable(tableKey)) return new Response('Not found', { status: 404 });
  const config = adminTables[tableKey];
  const { data, error } = await createSupabaseAdminClient().from(config.table).select(config.visibleColumns.join(',')).order(config.orderBy, { ascending: false }).limit(50000);
  if (error) return new Response('Export failed', { status: 500 });
  const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
  const csv = `\uFEFF${config.visibleColumns.join(',')}\n${rows.map((row) => config.visibleColumns.map((column) => csvCell(row[column])).join(',')).join('\n')}`;
  return new Response(csv, { headers: { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': `attachment; filename="link-${tableKey}.csv"` } });
}
