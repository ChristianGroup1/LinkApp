import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/data/models/models.dart';
import 'package:link/data/offline/member_create_draft.dart';
import 'package:link/data/offline/offline_save_result.dart';
import 'package:link/data/repositories/database_repository.dart';
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

  test('round-trips Excel details and creates the parsed member', () async {
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

    final repository = _RecordingRepository();
    final saved = await MemberImportWriter().save(
      rows: parsed.validRows,
      repository: repository,
    );

    expect(saved.imported, 1);
    expect(saved.issues, isEmpty);
    expect(repository.created.single.fullName, 'مينا سمير');
    expect(repository.created.single.sundaySchoolClassId, 'class-1');
    expect(repository.created.single.phone, '01000000000');
  });

  test('parses UTF-8 CSV and creates active and inactive members', () async {
    final csv = '''\uFEFF${memberExcelHeaders.join(';')}
"مينا، سمير";فصل;اجتماع مدارس الأحد;أولى ابتدائي;2014-05-20;01000000000;CSV-1;سمير;01100000000;نعم
ماريا فادي;فصل;اجتماع مدارس الأحد;أولى ابتدائي;2015-06-21;01200000000;CSV-2;;;لا
''';
    final service = MemberExcelService();
    final parsed = service.parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [meeting],
      classes: const [classEntity],
      existingMembers: const [],
    );

    expect(parsed.issues, isEmpty);
    expect(parsed.validRows, hasLength(2));
    expect(parsed.validRows.first.fullName, 'مينا، سمير');
    expect(parsed.validRows.first.phone, '01000000000');
    expect(parsed.validRows.first.sundaySchoolClassId, 'class-1');
    expect(parsed.validRows.last.isActive, isFalse);

    final repository = _RecordingRepository();
    final saved = await MemberImportWriter().save(
      rows: parsed.validRows,
      repository: repository,
    );

    expect(saved.imported, 2);
    expect(saved.issues, isEmpty);
    expect(repository.created.map((member) => member.code), ['CSV-1', 'CSV-2']);
    expect(repository.deactivatedIds, ['created-2']);
  });

  test('accepts comma-delimited CSV with a quoted comma in the name', () {
    const csv = '''الاسم الكامل *,نوع التبعية *,الاجتماع *,الفصل
"مينا, سمير",فصل,اجتماع مدارس الأحد,أولى ابتدائي
''';

    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [meeting],
      classes: const [classEntity],
      existingMembers: const [],
    );

    expect(parsed.issues, isEmpty);
    expect(parsed.validRows.single.fullName, 'مينا, سمير');
  });

  test(
    'creates missing meetings and classes once using selected weekdays',
    () async {
      const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
عضو مباشر;اجتماع;اجتماع الشباب;
طفل أول;فصل;اجتماع جديد لمدارس الأحد;فصل جديد
طفل ثان;فصل;اجتماع جديد لمدارس الأحد;فصل جديد
''';
      final parsed = MemberExcelService().parseCsvImport(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        meetings: const [],
        classes: const [],
        existingMembers: const [],
      );

      expect(parsed.issues, isEmpty);
      expect(parsed.validRows, hasLength(3));
      expect(
        parsed.meetingNamesToCreate,
        containsAll(['اجتماع الشباب', 'اجتماع جديد لمدارس الأحد']),
      );
      expect(parsed.classNamesToCreate, [
        'اجتماع جديد لمدارس الأحد ← فصل جديد',
      ]);

      final repository = _RecordingRepository();
      final saved = await MemberImportWriter().save(
        rows: parsed.validRows,
        repository: repository,
        meetingWeekdays: const {
          'اجتماع الشباب': 6,
          'اجتماع جديد لمدارس الأحد': 7,
        },
      );

      expect(saved.imported, 3);
      expect(saved.createdMeetings, 2);
      expect(saved.createdClasses, 1);
      expect(saved.issues, isEmpty);
      expect(
        repository.createdMeetings
            .singleWhere((item) => item.nameAr == 'اجتماع الشباب')
            .weekday,
        6,
      );
      final sundayMeeting = repository.createdMeetings.singleWhere(
        (item) => item.nameAr == 'اجتماع جديد لمدارس الأحد',
      );
      expect(sundayMeeting.kind, MeetingKind.sundaySchool);
      expect(sundayMeeting.weekday, 7);
      expect(repository.createdClasses.single.meetingId, sundayMeeting.id);
      expect(
        repository.created
            .where((member) => member.scope == MemberScope.sundaySchoolClass)
            .map((member) => member.sundaySchoolClassId)
            .toSet(),
        {repository.createdClasses.single.id},
      );
    },
  );

  test('rejects one new meeting name used for incompatible scopes', () {
    const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
عضو مباشر;اجتماع;اسم مكرر;
طفل;فصل;اسم مكرر;فصل جديد
''';

    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [],
      classes: const [],
      existingMembers: const [],
    );

    expect(parsed.validRows, isEmpty);
    expect(parsed.issues, hasLength(2));
    expect(parsed.issues.first.message, contains('استخدم اسمين مختلفين'));
  });

  test('detects a code already used and defaults it to duplicate review', () {
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

    expect(parsed.issues, isEmpty);
    expect(parsed.validRows, hasLength(1));
    expect(parsed.duplicates, hasLength(1));
    expect(parsed.duplicates.single.existingMember.id, 'existing-member');
    expect(parsed.duplicates.single.matchedBy, contains('الكود'));
  });

  test(
    'updates an existing duplicate instead of creating another member',
    () async {
      final existing = const MemberEntity(
        id: 'existing-member',
        churchId: 'church-1',
        fullName: 'عضو حالي',
        scope: MemberScope.sundaySchoolClass,
        sundaySchoolClassId: 'class-1',
        code: 'DUP-1',
        phone: '01000000000',
        isActive: true,
      );
      final bytes = MemberExcelService().exportMembers(
        members: [
          const MemberEntity(
            id: 'imported-member',
            churchId: 'church-1',
            fullName: 'الاسم بعد التحديث',
            scope: MemberScope.sundaySchoolClass,
            sundaySchoolClassId: 'class-1',
            code: 'DUP-1',
            phone: '01111111111',
            isActive: true,
          ),
        ],
        meetings: const [meeting],
        classes: const [classEntity],
      );
      final parsed = MemberExcelService().parseImport(
        bytes: bytes,
        meetings: const [meeting],
        classes: const [classEntity],
        existingMembers: [existing],
      );
      final duplicate = parsed.duplicates.single;
      final repository = _RecordingRepository(
        initialMeetings: const [meeting],
        initialClasses: const [classEntity],
      );

      final saved = await MemberImportWriter().save(
        rows: parsed.validRows,
        repository: repository,
        duplicatesByRow: {duplicate.row.sourceRow: duplicate},
        duplicateActions: {
          duplicate.row.sourceRow: MemberImportDuplicateAction.update,
        },
      );

      expect(saved.createdMembers, 0);
      expect(saved.updatedMembers, 1);
      expect(repository.created, isEmpty);
      expect(repository.updated.single.id, existing.id);
      expect(repository.updated.single.fullName, 'الاسم بعد التحديث');
    },
  );

  test(
    'removes destinations created by an import when all members fail',
    () async {
      const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
طفل;فصل;اجتماع سيفشل;فصل سيفشل
''';
      final parsed = MemberExcelService().parseCsvImport(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        meetings: const [],
        classes: const [],
        existingMembers: const [],
      );
      final repository = _RecordingRepository()..memberCreateFailures = 1;

      final saved = await MemberImportWriter().save(
        rows: parsed.validRows,
        repository: repository,
        meetingWeekdays: const {'اجتماع سيفشل': 4},
      );

      expect(saved.imported, 0);
      expect(saved.failedRows, hasLength(1));
      expect(saved.removedEmptyClasses, 1);
      expect(saved.removedEmptyMeetings, 1);
      expect(saved.createdClasses, 0);
      expect(saved.createdMeetings, 0);
      expect(repository.createdClasses, isEmpty);
      expect(repository.createdMeetings, isEmpty);
    },
  );

  test(
    'cancellation stops between rows and returns remaining rows for retry',
    () async {
      const directMeeting = MeetingEntity(
        id: 'meeting-direct',
        churchId: 'church-1',
        name: 'Youth',
        nameAr: 'اجتماع الشباب',
        kind: MeetingKind.normal,
        weekday: 5,
        isActive: true,
      );
      const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
عضو أول;اجتماع;اجتماع الشباب;
عضو ثان;اجتماع;اجتماع الشباب;
عضو ثالث;اجتماع;اجتماع الشباب;
''';
      final parsed = MemberExcelService().parseCsvImport(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        meetings: const [directMeeting],
        classes: const [],
        existingMembers: const [],
      );
      final repository = _RecordingRepository(
        initialMeetings: const [directMeeting],
      );
      var cancel = false;

      final saved = await MemberImportWriter().save(
        rows: parsed.validRows,
        repository: repository,
        onProgress: (progress) {
          if (progress.processed == 1) cancel = true;
        },
        isCancelled: () => cancel,
      );

      expect(saved.cancelled, isTrue);
      expect(saved.createdMembers, 1);
      expect(saved.failedRows, hasLength(2));
      expect(repository.created.single.fullName, 'عضو أول');
    },
  );

  test('builds a re-importable Excel error report', () {
    final bytes = MemberExcelService().buildIssuesWorkbook(const [
      MemberImportIssue(
        row: 7,
        message: 'الكود مكرر',
        suggestion: 'غيّر الكود',
        sourceValues: ['مينا', 'اجتماع', 'اجتماع الشباب'],
      ),
    ]);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables[MemberExcelService.membersSheetName];

    expect(sheet, isNotNull);
    final headerTexts = [
      for (final cell in sheet!.rows.first) cell?.value?.toString() ?? '',
    ];
    expect(headerTexts, containsAll(memberExcelHeaders));
    expect(
      headerTexts,
      containsAll(['رقم الصف الأصلي', 'سبب الخطأ', 'طريقة التصحيح']),
    );
    final rowTexts = [
      for (final cell in sheet.rows[1]) cell?.value?.toString() ?? '',
    ];
    expect(rowTexts, containsAll(['مينا', '7', 'الكود مكرر', 'غيّر الكود']));
  });

  test('saves large imports through batched server calls', () async {
    const directMeeting = MeetingEntity(
      id: 'meeting-direct',
      churchId: 'church-1',
      name: 'Youth',
      nameAr: 'اجتماع الشباب',
      kind: MeetingKind.normal,
      weekday: 5,
      isActive: true,
    );
    final csv = StringBuffer('الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل\n');
    for (var index = 1; index <= 5; index++) {
      csv.writeln('عضو رقم $index;اجتماع;اجتماع الشباب;');
    }
    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv.toString())),
      meetings: const [directMeeting],
      classes: const [],
      existingMembers: const [],
    );
    final repository = _RecordingRepository(
      initialMeetings: const [directMeeting],
    );

    final saved = await MemberImportWriter().save(
      rows: parsed.validRows,
      repository: repository,
      batchSize: 2,
    );

    expect(saved.imported, 5);
    expect(saved.issues, isEmpty);
    expect(repository.created, hasLength(5));
    // Two full batches of 2; the trailing single row is saved directly.
    expect(repository.batchCalls, 2);
    expect(saved.createdMemberIds, hasLength(5));
  });

  test('falls back to per-row saves when a whole batch fails', () async {
    const directMeeting = MeetingEntity(
      id: 'meeting-direct',
      churchId: 'church-1',
      name: 'Youth',
      nameAr: 'اجتماع الشباب',
      kind: MeetingKind.normal,
      weekday: 5,
      isActive: true,
    );
    const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
عضو أول;اجتماع;اجتماع الشباب;
عضو ثان;اجتماع;اجتماع الشباب;
''';
    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [directMeeting],
      classes: const [],
      existingMembers: const [],
    );
    final repository =
        _RecordingRepository(initialMeetings: const [directMeeting])
          ..failBatch = true
          ..memberCreateFailures = 1;

    final saved = await MemberImportWriter().save(
      rows: parsed.validRows,
      repository: repository,
    );

    expect(repository.batchCalls, 1);
    expect(saved.imported, 1);
    expect(saved.failedRows, hasLength(1));
    expect(saved.failedRows.single.fullName, 'عضو أول');
    expect(repository.created.single.fullName, 'عضو ثان');
  });

  test('undoImport deletes created members and restores updated ones', () async {
    const existing = MemberEntity(
      id: 'existing-member',
      churchId: 'church-1',
      fullName: 'الاسم القديم',
      scope: MemberScope.sundaySchoolClass,
      sundaySchoolClassId: 'class-1',
      code: 'DUP-1',
      isActive: true,
    );
    const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل
عضو جديد;فصل;اجتماع جديد;فصل جديد
''';
    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [],
      classes: const [],
      existingMembers: const [],
    );
    final repository = _RecordingRepository();
    final writer = MemberImportWriter();
    final saved = await writer.save(
      rows: parsed.validRows,
      repository: repository,
      meetingWeekdays: const {'اجتماع جديد': 7},
    );
    expect(saved.createdMemberIds, hasLength(1));
    expect(saved.createdMeetingIds, hasLength(1));
    expect(saved.createdClassIds, hasLength(1));

    final undo = await writer.undoImport(
      repository: repository,
      createdMemberIds: saved.createdMemberIds,
      updatedMemberPreviousVersions: const [existing],
      createdClassIds: saved.createdClassIds,
      createdMeetingIds: saved.createdMeetingIds,
    );

    expect(undo.removedMembers, 1);
    expect(undo.restoredMembers, 1);
    expect(undo.removedClasses, 1);
    expect(undo.removedMeetings, 1);
    expect(undo.issues, isEmpty);
    expect(repository.deletedMemberIds, saved.createdMemberIds);
    expect(repository.updated.single.fullName, 'الاسم القديم');
    expect(repository.createdMeetings, isEmpty);
    expect(repository.createdClasses, isEmpty);
  });

  test('warns about suspicious or repeated phones without blocking', () {
    const csv = '''الاسم الكامل *;نوع التبعية *;الاجتماع *;الفصل;رقم هاتف العضو
عضو أول;فصل;اجتماع مدارس الأحد;أولى ابتدائي;123
عضو ثان;فصل;اجتماع مدارس الأحد;أولى ابتدائي;01000000000
عضو ثالث;فصل;اجتماع مدارس الأحد;أولى ابتدائي;01000000000
''';

    final parsed = MemberExcelService().parseCsvImport(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      meetings: const [meeting],
      classes: const [classEntity],
      existingMembers: const [],
    );

    expect(parsed.issues, isEmpty);
    expect(parsed.validRows, hasLength(3));
    expect(parsed.warnings, hasLength(2));
    expect(parsed.warnings.first.message, contains('يبدو غير صحيح'));
    expect(parsed.warnings.last.message, contains('مكرر مع الصف'));
  });
}

class _RecordingRepository implements DatabaseRepository {
  final List<MemberEntity> created = [];
  final List<MemberEntity> updated = [];
  final List<MeetingEntity> createdMeetings;
  final List<SundaySchoolClassEntity> createdClasses;
  final List<String> deactivatedIds = [];
  final List<String> deletedMemberIds = [];
  int memberCreateFailures = 0;
  int batchCalls = 0;
  bool failBatch = false;

  _RecordingRepository({
    List<MeetingEntity> initialMeetings = const [],
    List<SundaySchoolClassEntity> initialClasses = const [],
  }) : createdMeetings = List.of(initialMeetings),
       createdClasses = List.of(initialClasses);

  @override
  Future<List<MeetingEntity>> getMeetings() async => createdMeetings;

  @override
  Future<List<SundaySchoolClassEntity>> getAllSundaySchoolClasses() async =>
      createdClasses;

  @override
  Future<OfflineSaveResult<MeetingEntity>> createMeeting({
    required String name,
    required String nameAr,
    required MeetingKind kind,
    required int weekday,
    int? attendanceReminderMinutes,
    String? description,
  }) async {
    final meeting = MeetingEntity(
      id: 'meeting-created-${createdMeetings.length + 1}',
      churchId: 'church-1',
      name: name,
      nameAr: nameAr,
      kind: kind,
      weekday: weekday,
      isActive: true,
    );
    createdMeetings.add(meeting);
    return OfflineSaveResult(data: meeting, syncedToServer: true);
  }

  @override
  Future<OfflineSaveResult<SundaySchoolClassEntity>> createSundaySchoolClass({
    required String meetingId,
    required String name,
    required String nameAr,
    required int displayOrder,
  }) async {
    final classEntity = SundaySchoolClassEntity(
      id: 'class-created-${createdClasses.length + 1}',
      churchId: 'church-1',
      meetingId: meetingId,
      name: name,
      nameAr: nameAr,
      displayOrder: displayOrder,
      isActive: true,
    );
    createdClasses.add(classEntity);
    return OfflineSaveResult(data: classEntity, syncedToServer: true);
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> createMember({
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    String? notes,
  }) async {
    if (memberCreateFailures > 0) {
      memberCreateFailures--;
      throw StateError('فشل تجريبي في إنشاء العضو');
    }
    final member = MemberEntity(
      id: 'created-${created.length + 1}',
      churchId: 'church-1',
      fullName: fullName,
      scope: scope,
      sundaySchoolClassId: sundaySchoolClassId,
      meetingId: meetingId,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      code: code,
      birthDate: birthDate,
      notes: notes,
      isActive: true,
    );
    created.add(member);
    return OfflineSaveResult(data: member, syncedToServer: true);
  }

  @override
  Future<List<OfflineSaveResult<MemberEntity>>> createMembers(
    List<MemberCreateDraft> drafts,
  ) async {
    batchCalls++;
    if (failBatch) throw StateError('فشل تجريبي في دفعة الأعضاء');
    return [
      for (final draft in drafts)
        await createMember(
          fullName: draft.fullName,
          scope: draft.scope,
          sundaySchoolClassId: draft.sundaySchoolClassId,
          meetingId: draft.meetingId,
          phone: draft.phone,
          parentName: draft.parentName,
          parentPhone: draft.parentPhone,
          code: draft.code,
          birthDate: draft.birthDate,
        ),
    ];
  }

  @override
  Future<bool> deleteMember(String id) async {
    deletedMemberIds.add(id);
    created.removeWhere((member) => member.id == id);
    return true;
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> updateMember({
    required String id,
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    required bool isActive,
    String? notes,
  }) async {
    if (!isActive) deactivatedIds.add(id);
    final member = MemberEntity(
      id: id,
      churchId: 'church-1',
      fullName: fullName,
      scope: scope,
      sundaySchoolClassId: sundaySchoolClassId,
      meetingId: meetingId,
      phone: phone,
      parentName: parentName,
      parentPhone: parentPhone,
      code: code,
      birthDate: birthDate,
      notes: notes,
      isActive: isActive,
    );
    updated.add(member);
    return OfflineSaveResult(data: member, syncedToServer: true);
  }

  @override
  Future<List<MemberEntity>> getClassMembers(String classId) async =>
      created.where((member) => member.sundaySchoolClassId == classId).toList();

  @override
  Future<List<MemberEntity>> getMeetingMembers(String meetingId) async =>
      created.where((member) => member.meetingId == meetingId).toList();

  @override
  Future<bool> deleteSundaySchoolClass(String id) async {
    createdClasses.removeWhere((item) => item.id == id);
    return true;
  }

  @override
  Future<bool> deleteMeeting(String id) async {
    createdMeetings.removeWhere((item) => item.id == id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
