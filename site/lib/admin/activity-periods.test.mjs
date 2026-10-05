import test from 'node:test';
import assert from 'node:assert/strict';
import { activityWindows, cairoMidnight, countActivity } from './activity-periods.ts';

const now = new Date('2026-10-05T12:00:00Z');
const event = (id, at, name = 'app_open') => ({ user_id: id, occurred_at: at, event_name: name });

test('Cairo midnight follows winter and summer offsets', () => {
  assert.equal(cairoMidnight('2026-01-05').toISOString(), '2026-01-04T22:00:00.000Z');
  assert.equal(cairoMidnight('2026-10-05').toISOString(), '2026-10-04T21:00:00.000Z');
});

test('unique users distinguish Cairo today from the last 24 hours', () => {
  const ranges = activityWindows({ activity: 'week' }, now);
  const counts = countActivity([
    event('today', '2026-10-04T22:00:00Z'),
    event('today', '2026-10-05T11:59:00Z', 'sign_in'),
    event('yesterday', '2026-10-04T13:00:00Z'),
    event('week', '2026-10-01T12:00:00Z'),
    event('month', '2026-09-10T12:00:00Z'),
    event(null, '2026-10-05T11:59:00Z'),
    event('unsupported', '2026-10-05T11:59:00Z', 'other'),
    event('future', '2026-10-06T12:00:00Z'),
  ], ranges);
  assert.deepEqual(counts, { today: 1, day: 2, week: 3, month: 4, selected: 3, recent: 1 });
});

test('custom dates include the whole final Cairo day and exclude the next midnight', () => {
  const ranges = activityWindows({ activity: 'custom', activityFrom: '2026-09-01', activityTo: '2026-09-02' }, now);
  assert.equal(ranges.error, null);
  const counts = countActivity([
    event('first', '2026-08-31T21:00:00Z'),
    event('last', '2026-09-02T20:59:59Z'),
    event('outside', '2026-09-02T21:00:00Z'),
  ], ranges);
  assert.equal(counts.selected, 2);
  assert.equal(ranges.queryStart.toISOString(), '2026-08-31T21:00:00.000Z');
});

test('invalid dates, reversed dates, and future starts return a validation error', () => {
  for (const [from, to] of [['2026-02-30', '2026-03-01'], ['2026-09-10', '2026-09-01'], ['2026-11-01', '2026-11-02'], ['', '']]) {
    const ranges = activityWindows({ activity: 'custom', activityFrom: from, activityTo: to }, now);
    assert.ok(ranges.error);
    assert.equal(ranges.selected, null);
  }
});

test('today remains independently counted when the selected period is historical', () => {
  const ranges = activityWindows({ activity: 'custom', activityFrom: '2026-07-01', activityTo: '2026-07-31' }, now);
  const counts = countActivity([event('old', '2026-07-10T12:00:00Z'), event('new', '2026-10-05T11:00:00Z')], ranges);
  assert.equal(counts.today, 1);
  assert.equal(counts.selected, 1);
});
