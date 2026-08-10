import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/features/members/data/member_excel_service.dart';

void main() {
  const meeting = MeetingEntity(
    id: 'meeting-1',
    churchId: 'church-1',
    name: 'Sunday School',
    nameAr: 'اجتماع مدارس الأحد',
    kind: MeetingKind.sundaySchool,
    weekday: 7,
    isActive: true,
  );
  const classEntity = SundaySchoolClassEntity(
    id: 'class-1',
    churchId: 'church-1',
    meetingId: 'meeting-1',
    name: 'Primary One',
    nameAr: 'أولى ابتدائي',
    displayOrder: 1,
    isActive: true,
  );

  test('builds an import template with guidance sheets', () {
    final bytes = MemberExcelService().buildTemplate(
      meetings: const [meeting],
      classes: const [classEntity],
    );
    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys, contains(MemberExcelService.membersSheetName));
    expect(workbook.tables.keys, contains('القيم المتاحة'));
    expect(workbook.tables.keys, contains('تعليمات'));
    expect(
      workbook.tables[MemberExcelService.membersSheetName]!.maxColumns,
      memberExcelHeaders.length,
    );
  });

  test('round-trips exported member details through import parsing', () {
    final service = MemberExcelService();
    final bytes = service.exportMembers(
      members: [
        MemberEntity(
          id: 'member-1',
          churchId: 'church-1',
          fullName: 'مينا سمير',
          scope: MemberScope.sundaySchoolClass,
          sundaySchoolClassId: 'class-1',
          phone: '01000000000',
          parentName: 'سمير حنا',
          parentPhone: '01100000000',
          code: 'MEM-1',
          isActive: true,
          birthDate: DateTime(2014, 5, 20),
        ),
      ],
      meetings: const [meeting],
      classes: const [classEntity],
    );

    final parsed = service.parseImport(
      bytes: bytes,
      meetings: const [meeting],
      classes: const [classEntity],
      existingMembers: const [],
    );

    expect(parsed.issues, isEmpty);
    expect(parsed.validRows, hasLength(1));
    final row = parsed.validRows.single;
    expect(row.fullName, 'مينا سمير');
    expect(row.scope, MemberScope.sundaySchoolClass);
    expect(row.sundaySchoolClassId, 'class-1');
    expect(row.phone, '01000000000');
    expect(row.code, 'MEM-1');
    expect(row.birthDate, DateTime(2014, 5, 20));
  });

  test('rejects a code already used by an existing member', () {
    final service = MemberExcelService();
    final bytes = service.exportMembers(
      members: [
        const MemberEntity(
          id: 'imported-member',
          churchId: 'church-1',
          fullName: 'عضو جديد',
          scope: MemberScope.sundaySchoolClass,
          sundaySchoolClassId: 'class-1',
          code: 'DUP-1',
          isActive: true,
        ),
      ],
      meetings: const [meeting],
      classes: const [classEntity],
    );

    final parsed = service.parseImport(
      bytes: bytes,
      meetings: const [meeting],
      classes: const [classEntity],
      existingMembers: const [
        MemberEntity(
          id: 'existing-member',
          churchId: 'church-1',
          fullName: 'عضو حالي',
          scope: MemberScope.sundaySchoolClass,
          sundaySchoolClassId: 'class-1',
          code: 'DUP-1',
          isActive: true,
        ),
      ],
    );

    expect(parsed.validRows, isEmpty);
    expect(parsed.issues.single.message, contains('مستخدم من قبل'));
  });
}
