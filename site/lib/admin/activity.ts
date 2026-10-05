import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { activityWindows, countActivity, type ActivitySearch, type UsageEvent } from './activity-periods';

export async function getUserActivity(search: ActivitySearch, churchId?: string) {
  const ranges = activityWindows(search);
  const admin = createSupabaseAdminClient();
  const events: UsageEvent[] = [];
  let lastId: string | undefined;
  // Fetch every matching event. A .limit(100000) alone still obeys the
  // database API's row cap and can silently undercount distinct users.
  while (true) {
    let query = admin.from('app_usage_events')
      .select('id, user_id, event_name, occurred_at')
      .in('event_name', ['app_open', 'sign_in'])
      .gte('occurred_at', ranges.queryStart.toISOString())
      .lt('occurred_at', ranges.windows.today.end.toISOString())
      .order('id').limit(1000);
    if (churchId) query = query.eq('church_id', churchId);
    if (lastId) query = query.gt('id', lastId);
    const { data, error } = await query;
    if (error) return { ...ranges, ready: false, counts: null };
    if (!data?.length) break;
    events.push(...data);
    lastId = data[data.length - 1].id;
  }
  return { ...ranges, ready: true, counts: countActivity(events, ranges) };
}
