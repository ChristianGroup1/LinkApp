import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/logic/home/home_bloc.dart';

void main() {
  const baseMember = MemberEntity(
    id: 'member-1',
    churchId: 'church-1',
    fullName: 'مينا سمير',
    scope: MemberScope.meeting,
    meetingId: 'meeting-1',
    isActive: true,
  );

  test('findUpcomingBirthdays includes today and the next 30 days', () {
    final members = [
      MemberEntity(
        id: baseMember.id,
        churchId: baseMember.churchId,
        fullName: baseMember.fullName,
        scope: baseMember.scope,
        meetingId: baseMember.meetingId,
        isActive: baseMember.isActive,
        birthDate: DateTime(2010, 7, 31),
      ),
      MemberEntity(
        id: 'member-2',
        churchId: baseMember.churchId,
        fullName: 'ماريا جرجس',
        scope: baseMember.scope,
        meetingId: baseMember.meetingId,
        isActive: true,
        birthDate: DateTime(2012, 8, 15),
      ),
      MemberEntity(
        id: 'member-3',
        churchId: baseMember.churchId,
        fullName: 'بعيد عن الفترة',
        scope: baseMember.scope,
        meetingId: baseMember.meetingId,
        isActive: true,
        birthDate: DateTime(2011, 11, 1),
      ),
    ];

    final result = findUpcomingBirthdays(members, DateTime(2026, 7, 31));

    expect(result.map((item) => item.member.id), ['member-1', 'member-2']);
    expect(result.first.daysUntil, 0);
    expect(result.first.turningAge, 16);
    expect(result.last.daysUntil, 15);
  });

  test('findUpcomingBirthdays rolls past birthdays into the next year', () {
    final member = MemberEntity(
      id: baseMember.id,
      churchId: baseMember.churchId,
      fullName: baseMember.fullName,
      scope: baseMember.scope,
      meetingId: baseMember.meetingId,
      isActive: baseMember.isActive,
      birthDate: DateTime(2010, 1, 5),
    );

    final result = findUpcomingBirthdays([member], DateTime(2026, 12, 20));

    expect(result.single.nextBirthday, DateTime(2027, 1, 5));
    expect(result.single.daysUntil, 16);
    expect(result.single.turningAge, 17);
  });

  test('findUpcomingBirthdays treats leap-day birthdays as February 28', () {
    final member = MemberEntity(
      id: baseMember.id,
      churchId: baseMember.churchId,
      fullName: baseMember.fullName,
      scope: baseMember.scope,
      meetingId: baseMember.meetingId,
      isActive: baseMember.isActive,
      birthDate: DateTime(2012, 2, 29),
    );

    final result = findUpcomingBirthdays([member], DateTime(2027, 2, 27));

    expect(result.single.nextBirthday, DateTime(2027, 2, 28));
    expect(result.single.daysUntil, 1);
  });
}
