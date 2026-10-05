const DAY = 86_400_000;
export type ActivityPeriod = 'today' | 'day' | 'week' | 'month' | 'custom';
export type ActivitySearch = { activity?: string; activityFrom?: string; activityTo?: string };
export type UsageEvent = { user_id: string | null; event_name: string; occurred_at: string };

export function cairoDate(date: Date): string {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(date);
  const get = (type: string) => parts.find((part) => part.type === type)!.value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

function validDate(value: string | undefined): value is string {
  return !!value && /^\d{4}-\d{2}-\d{2}$/.test(value)
    && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
}

// Resolve local midnight using the actual Cairo offset, including DST.
export function cairoMidnight(date: string): Date {
  const target = Date.parse(`${date}T00:00:00Z`);
  let value = target;
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  });
  for (let i = 0; i < 3; i++) {
    const parts = formatter.formatToParts(new Date(value));
    const get = (type: string) => parts.find((part) => part.type === type)!.value;
    const local = Date.parse(`${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}:${get('second')}Z`);
    value += target - local;
  }
  return new Date(value);
}

export function activityWindows(search: ActivitySearch, now = new Date()) {
  const today = cairoDate(now);
  const period: ActivityPeriod = ['today', 'day', 'week', 'month', 'custom'].includes(search.activity ?? '')
    ? search.activity as ActivityPeriod : 'week';
  const windows = {
    today: { start: cairoMidnight(today), end: now },
    day: { start: new Date(now.getTime() - DAY), end: now },
    week: { start: new Date(now.getTime() - 7 * DAY), end: now },
    month: { start: new Date(now.getTime() - 30 * DAY), end: now },
  };
  let error: string | null = null;
  let selected: { start: Date; end: Date } | null = null;
  if (period === 'custom') {
    if (!validDate(search.activityFrom) || !validDate(search.activityTo)) {
      error = 'حدد تاريخ البداية والنهاية للفترة.';
    } else if (search.activityFrom > search.activityTo || search.activityFrom > today) {
      error = 'تاريخ البداية لازم يكون قبل النهاية، ومش بعد النهارده.';
    } else {
      const nextDay = new Date(Date.parse(search.activityTo) + DAY).toISOString().slice(0, 10);
      selected = { start: cairoMidnight(search.activityFrom), end: new Date(Math.min(now.getTime(), cairoMidnight(nextDay).getTime())) };
    }
  } else selected = windows[period];
  return { period, today, windows, selected, error,
    from: validDate(search.activityFrom) ? search.activityFrom : cairoDate(windows.month.start),
    to: validDate(search.activityTo) ? search.activityTo : today,
    queryStart: new Date(Math.min(windows.month.start.getTime(), windows.today.start.getTime(), selected?.start.getTime() ?? now.getTime())),
  };
}

export function countActivity(events: UsageEvent[], ranges: ReturnType<typeof activityWindows>) {
  const sets = { today: new Set<string>(), day: new Set<string>(), week: new Set<string>(), month: new Set<string>(), selected: new Set<string>(), recent: new Set<string>() };
  const recentStart = ranges.windows.today.end.getTime() - 5 * 60_000;
  for (const event of events) {
    if (!event.user_id || !['app_open', 'sign_in'].includes(event.event_name)) continue;
    const at = Date.parse(event.occurred_at);
    for (const key of ['today', 'day', 'week', 'month'] as const) {
      if (at >= ranges.windows[key].start.getTime() && at < ranges.windows[key].end.getTime()) sets[key].add(event.user_id);
    }
    if (ranges.selected && at >= ranges.selected.start.getTime() && at < ranges.selected.end.getTime()) sets.selected.add(event.user_id);
    if (at >= recentStart && at < ranges.windows.today.end.getTime()) sets.recent.add(event.user_id);
  }
  return Object.fromEntries(Object.entries(sets).map(([key, value]) => [key, value.size])) as Record<keyof typeof sets, number>;
}
