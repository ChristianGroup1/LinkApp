type MeetingGroup = {
  id: string;
  church: string;
  meeting: string;
  servants: string[];
  members: string[];
  memberCount: number;
};

export function buildMeetingGroups({
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
  for (const assignment of memberMeetingAssignments) {
    const memberId = String(assignment.member_id);
    const meetingId = String(assignment.meeting_id);
    const member = activeMemberById.get(memberId);
    if (member && String(member.church_id) === String(assignment.church_id)
      && meetingChurchById.get(meetingId) === String(assignment.church_id)) {
      addMeetingMember(meetingId, memberId);
    }
  }
  const classById = new Map(classes.map((schoolClass) => [String(schoolClass.id), schoolClass]));
  for (const member of activeMembers) {
    const memberId = String(member.id);
    const schoolClass = classById.get(String(member.sunday_school_class_id));
    const classMeetingId = schoolClass && String(schoolClass.church_id) === String(member.church_id)
      ? schoolClass.meeting_id : null;
    // Additional assignments never replace the primary meeting or class.
    for (const id of [member.meeting_id, classMeetingId]) {
      const meetingId = typeof id === 'string' ? id : '';
      if (meetingId && meetingChurchById.get(meetingId) === String(member.church_id)) {
        addMeetingMember(meetingId, memberId);
      }
    }
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

