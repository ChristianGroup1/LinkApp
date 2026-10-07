import test from 'node:test';
import assert from 'node:assert/strict';
import { buildMeetingGroups } from './meeting-groups.ts';
import { readCompleteRows } from './read-complete-rows.ts';

function fixture(members = []) {
  return {
    churches: [{ id: 'church', name_ar: 'كنيسة الاخوة بكردوس' }], profiles: [],
    meetings: [{ id: 'youth', church_id: 'church', name_ar: 'اجتماع الشباب (اعدادي ثانوي جامعه)' },
      { id: 'other', church_id: 'church' }, { id: 'foreign', church_id: 'foreign-church' }],
    classes: [{ id: 'class', church_id: 'church', meeting_id: 'youth' }], members,
    memberMeetingAssignments: [], meetingAssignments: [],
  };
}
const member = (id, extra = {}) => ({ id, church_id: 'church', full_name: id, is_active: true, meeting_id: 'youth', ...extra });

test('44 primary members remain counted when also assigned to another meeting', () => {
  const data = fixture(Array.from({ length: 44 }, (_, i) => member(`member-${i}`)));
  data.memberMeetingAssignments = data.members.map(m => ({ church_id: 'church', member_id: m.id, meeting_id: 'other' }));
  const groups = buildMeetingGroups(data);
  assert.equal(groups.find(g => g.id === 'youth').memberCount, 44);
  assert.equal(groups.find(g => g.id === 'other').memberCount, 44);
});

test('primary, class, and copied links count each active member once and isolate churches', () => {
  const data = fixture([member('primary'), member('class', { meeting_id: null, sunday_school_class_id: 'class' }),
    member('copied', { meeting_id: null }), member('inactive', { is_active: false }), member('wrong-church', { church_id: 'foreign-church' })]);
  data.memberMeetingAssignments = [
    { church_id: 'church', member_id: 'primary', meeting_id: 'youth' },
    { church_id: 'church', member_id: 'class', meeting_id: 'other' },
    { church_id: 'church', member_id: 'copied', meeting_id: 'youth' },
    { church_id: 'church', member_id: 'wrong-church', meeting_id: 'youth' },
    { church_id: 'church', member_id: 'primary', meeting_id: 'foreign' },
  ];
  const groups = buildMeetingGroups(data);
  assert.equal(groups.find(g => g.id === 'youth').memberCount, 3);
  assert.equal(groups.find(g => g.id === 'foreign').memberCount, 0);
});

test('complete loading includes 44 members beyond the first API page and handles smaller caps', async () => {
  const rows = [...Array.from({ length: 1000 }, (_, i) => member(`other-${i}`, { meeting_id: 'other' })),
    ...Array.from({ length: 44 }, (_, i) => member(`youth-${i}`))];
  for (const cap of [1000, 100]) {
    const loaded = await readCompleteRows(async (from, to) => ({ data: rows.slice(from, Math.min(to + 1, from + cap)), error: null }));
    assert.equal(loaded.length, 1044);
    assert.equal(buildMeetingGroups(fixture(loaded)).find(g => g.id === 'youth').memberCount, 44);
  }
});

test('a failed later page never produces a partial count', async () => {
  await assert.rejects(() => readCompleteRows(async from => from === 0
    ? { data: [member('first')], error: null }
    : { data: null, error: { message: 'unavailable' } }), /تعذر تحميل/);
});
