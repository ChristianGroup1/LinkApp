import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/arabic_error_text.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/member_create_draft.dart';
import '../../../data/offline/offline_save_result.dart';
import '../../../data/repositories/database_repository.dart';

const memberExcelHeaders = [
  'الاسم الكامل *',
  'نوع التبعية *',
  'الاجتماع *',
  'الفصل',
  'تاريخ الميلاد (YYYY-MM-DD)',
  'رقم هاتف العضو',
  'الكود التعريفي',
  'اسم ولي الأمر',
  'هاتف ولي الأمر',
  'نشط (نعم/لا)',
];

class MemberImportRow {
  final int sourceRow;
  final String fullName;
  final MemberScope scope;
  final String meetingName;
  final String? className;
  final String? sundaySchoolClassId;
  final String? meetingId;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final DateTime? birthDate;
  final bool isActive;

  const MemberImportRow({
    required this.sourceRow,
    required this.fullName,
    required this.scope,
    required this.meetingName,
    this.className,
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    this.birthDate,
    required this.isActive,
  });

  List<String> toCsvValues() => [
    fullName,
    scope == MemberScope.sundaySchoolClass ? 'فصل' : 'اجتماع',
    meetingName,
    className ?? '',
    MemberExcelService._formatDate(birthDate),
    phone ?? '',
    code ?? '',
    parentName ?? '',
    parentPhone ?? '',
    isActive ? 'نعم' : 'لا',
  ];
}

class MemberImportIssue {
  final int row;
  final String message;
  final String suggestion;
  final List<String> sourceValues;
  final MemberImportRow? importRow;

  const MemberImportIssue({
    required this.row,
    required this.message,
    this.suggestion = 'راجع بيانات الصف ثم أعد المحاولة',
    this.sourceValues = const [],
    this.importRow,
  });
}

enum MemberImportDuplicateAction { skip, update, createNew }

class MemberImportDuplicate {
  final MemberImportRow row;
  final MemberEntity existingMember;
  final List<String> matchedBy;

  const MemberImportDuplicate({
    required this.row,
    required this.existingMember,
    required this.matchedBy,
  });

  bool get codeMatched => matchedBy.contains('الكود');
}

class MemberImportParseResult {
  final List<MemberImportRow> validRows;
  final List<MemberImportIssue> issues;

  /// Non-blocking notes (e.g. suspicious phone numbers); rows stay importable.
  final List<MemberImportIssue> warnings;
  final List<MemberImportDuplicate> duplicates;

  const MemberImportParseResult({
    required this.validRows,
    required this.issues,
    this.warnings = const [],
    this.duplicates = const [],
  });

  List<String> get meetingNamesToCreate {
    final names = <String, String>{};
    for (final row in validRows.where((row) => row.meetingId == null)) {
      names.putIfAbsent(
        MemberExcelService._normalize(row.meetingName),
        () => row.meetingName,
      );
    }
    return names.values.toList(growable: false);
  }

  List<String> get classNamesToCreate {
    final names = <String, String>{};
    for (final row in validRows.where(
      (row) =>
          row.scope == MemberScope.sundaySchoolClass &&
          row.sundaySchoolClassId == null,
    )) {
      final className = row.className;
      if (className == null) continue;
      final key =
          '${MemberExcelService._normalize(row.meetingName)}|'
          '${MemberExcelService._normalize(className)}';
      names.putIfAbsent(key, () => '${row.meetingName} ← $className');
    }
    return names.values.toList(growable: false);
  }
}

class MemberImportSaveResult {
  final int imported;
  final int createdMembers;
  final int updatedMembers;
  final int skippedMembers;
  final int createdMeetings;
  final int createdClasses;
  final int removedEmptyMeetings;
  final int removedEmptyClasses;
  final bool savedOffline;
  final bool cancelled;
  final List<MemberImportIssue> issues;
  final List<MemberImportRow> failedRows;
  final List<String> createdMemberIds;

  /// Pre-update snapshots of members changed by «تحديث الموجود», for undo.
  final List<MemberEntity> updatedMemberPreviousVersions;
  final List<String> createdMeetingIds;
  final List<String> createdClassIds;

  const MemberImportSaveResult({
    required this.imported,
    this.createdMembers = 0,
    this.updatedMembers = 0,
    this.skippedMembers = 0,
    this.createdMeetings = 0,
    this.createdClasses = 0,
    this.removedEmptyMeetings = 0,
    this.removedEmptyClasses = 0,
    this.savedOffline = false,
    this.cancelled = false,
    required this.issues,
    this.failedRows = const [],
    this.createdMemberIds = const [],
    this.updatedMemberPreviousVersions = const [],
    this.createdMeetingIds = const [],
    this.createdClassIds = const [],
  });
}

class MemberImportUndoResult {
  final int removedMembers;
  final int restoredMembers;
  final int removedMeetings;
  final int removedClasses;
  final List<MemberImportIssue> issues;

  const MemberImportUndoResult({
    required this.removedMembers,
    required this.restoredMembers,
    required this.removedMeetings,
    required this.removedClasses,
    required this.issues,
  });
}

class MemberImportParseRequest {
  final Uint8List bytes;
  final bool isCsv;
  final List<MeetingEntity> meetings;
  final List<SundaySchoolClassEntity> classes;
  final List<MemberEntity> existingMembers;

  const MemberImportParseRequest({
    required this.bytes,
    required this.isCsv,
    required this.meetings,
    required this.classes,
    required this.existingMembers,
  });
}

MemberImportParseResult _parseMemberImportInBackground(
  MemberImportParseRequest request,
) {
  final service = MemberExcelService();
  return request.isCsv
      ? service.parseCsvImport(
          bytes: request.bytes,
          meetings: request.meetings,
          classes: request.classes,
          existingMembers: request.existingMembers,
        )
      : service.parseImport(
          bytes: request.bytes,
          meetings: request.meetings,
          classes: request.classes,
          existingMembers: request.existingMembers,
        );
}

class MemberImportProgress {
  final int processed;
  final int total;
  final int imported;
  final int failed;
  final int skipped;
  final int? currentRow;

  const MemberImportProgress({
    required this.processed,
    required this.total,
    required this.imported,
    required this.failed,
    required this.skipped,
    this.currentRow,
  });
}

class MemberImportWriter {
  Future<MemberImportSaveResult> save({
    required List<MemberImportRow> rows,
    required DatabaseRepository repository,
    Map<String, int> meetingWeekdays = const {},
    Map<int, MemberImportDuplicate> duplicatesByRow = const {},
    Map<int, MemberImportDuplicateAction> duplicateActions = const {},
    void Function(MemberImportProgress progress)? onProgress,
    bool Function()? isCancelled,
    int batchSize = 25,
  }) async {
    var imported = 0;
    var createdMembers = 0;
    var updatedMembers = 0;
    var skippedMembers = 0;
    var createdMeetings = 0;
    var createdClasses = 0;
    var removedEmptyMeetings = 0;
    var removedEmptyClasses = 0;
    var processed = 0;
    var cancelled = false;
    var allSyncedToServer = true;
    final issues = <MemberImportIssue>[];
    final failedRows = <MemberImportRow>[];
    final meetingIdsByName = <String, String>{};
    final classIdsByName = <String, String>{};
    final failedDestinations = <String, Object>{};
    final nextClassOrderByMeeting = <String, int>{};
    final createdMeetingNamesById = <String, String>{};
    final createdClassNamesById = <String, String>{};
    final createdClassMeetingIds = <String, String>{};
    final successfulMeetingIds = <String>{};
    final successfulClassIds = <String>{};

    void report({int? currentRow}) {
      onProgress?.call(
        MemberImportProgress(
          processed: processed,
          total: rows.length,
          imported: imported,
          failed: failedRows.length,
          skipped: skippedMembers,
          currentRow: currentRow,
        ),
      );
    }

    report();

    try {
      final meetings = await repository.getMeetings();
      final classes = await repository.getAllSundaySchoolClasses();
      for (final meeting in meetings) {
        meetingIdsByName[MemberExcelService._normalize(meeting.nameAr)] =
            meeting.id;
        meetingIdsByName[MemberExcelService._normalize(meeting.name)] =
            meeting.id;
      }
      for (final classEntity in classes) {
        final meeting = meetings
            .where((item) => item.id == classEntity.meetingId)
            .firstOrNull;
        if (meeting == null) continue;
        for (final meetingName in [meeting.nameAr, meeting.name]) {
          final meetingKey = MemberExcelService._normalize(meetingName);
          for (final className in [classEntity.nameAr, classEntity.name]) {
            classIdsByName['$meetingKey|'
                    '${MemberExcelService._normalize(className)}'] =
                classEntity.id;
          }
        }
        final nextOrder = classEntity.displayOrder + 1;
        if (nextOrder > (nextClassOrderByMeeting[meeting.id] ?? 0)) {
          nextClassOrderByMeeting[meeting.id] = nextOrder;
        }
      }
    } catch (_) {
      // The parsed IDs and local offline cache remain sufficient to continue.
    }

    final plannedMeetingKinds = <String, MeetingKind>{};
    final normalizedMeetingWeekdays = {
      for (final entry in meetingWeekdays.entries)
        MemberExcelService._normalize(entry.key): entry.value,
    };
    for (final row in rows.where((row) => row.meetingId == null)) {
      final key = MemberExcelService._normalize(row.meetingName);
      final requiredKind = row.scope == MemberScope.sundaySchoolClass
          ? MeetingKind.sundaySchool
          : MeetingKind.normal;
      if (requiredKind == MeetingKind.sundaySchool) {
        plannedMeetingKinds[key] = requiredKind;
      } else {
        plannedMeetingKinds.putIfAbsent(key, () => requiredKind);
      }
    }

    final pendingCreates = <_PendingMemberCreate>[];
    final createdMemberIds = <String>[];
    final updatedPreviousVersions = <MemberEntity>[];

    void markDestinationSuccess(
      MemberImportRow row,
      String meetingId,
      String? classId,
    ) {
      if (row.scope == MemberScope.sundaySchoolClass) {
        successfulClassIds.add(classId!);
      } else {
        successfulMeetingIds.add(meetingId);
      }
    }

    Future<void> deactivateCreated(
      MemberImportRow row,
      MemberEntity member,
    ) async {
      try {
        final updated = await repository.updateMember(
          id: member.id,
          fullName: member.fullName,
          scope: member.scope,
          sundaySchoolClassId: member.sundaySchoolClassId,
          meetingId: member.meetingId,
          phone: member.phone,
          parentName: member.parentName,
          parentPhone: member.parentPhone,
          code: member.code,
          birthDate: member.birthDate,
          isActive: false,
          notes: member.notes,
        );
        allSyncedToServer = allSyncedToServer && updated.syncedToServer;
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: row.sourceRow,
            message:
                'تم إنشاء العضو، لكن تعذر تحويله إلى غير نشط: ${_errorText(error)}',
            suggestion: 'افتح بيانات العضو وعطّل حالة «نشط» يدويًا',
            sourceValues: row.toCsvValues(),
          ),
        );
      }
    }

    Future<void> registerCreated(
      _PendingMemberCreate item,
      OfflineSaveResult<MemberEntity> created,
    ) async {
      allSyncedToServer = allSyncedToServer && created.syncedToServer;
      createdMembers++;
      createdMemberIds.add(created.data.id);
      markDestinationSuccess(item.row, item.meetingId, item.classId);
      imported++;
      if (!item.row.isActive) await deactivateCreated(item.row, created.data);
    }

    Future<void> flushPendingCreates() async {
      if (pendingCreates.isEmpty) return;
      final batch = List.of(pendingCreates);
      pendingCreates.clear();

      List<OfflineSaveResult<MemberEntity>>? batchResults;
      if (batch.length > 1) {
        try {
          batchResults = await repository.createMembers([
            for (final item in batch) item.draft,
          ]);
        } catch (_) {
          // The server rejected the whole batch; retry rows one by one below
          // so a single bad row doesn't fail its neighbours.
          batchResults = null;
        }
      }

      if (batchResults != null && batchResults.length == batch.length) {
        for (var index = 0; index < batch.length; index++) {
          await registerCreated(batch[index], batchResults[index]);
        }
      } else {
        for (final item in batch) {
          try {
            final created = await repository.createMember(
              fullName: item.draft.fullName,
              scope: item.draft.scope,
              sundaySchoolClassId: item.draft.sundaySchoolClassId,
              meetingId: item.draft.meetingId,
              phone: item.draft.phone,
              parentName: item.draft.parentName,
              parentPhone: item.draft.parentPhone,
              code: item.draft.code,
              birthDate: item.draft.birthDate,
            );
            await registerCreated(item, created);
          } catch (error) {
            failedRows.add(item.row);
            issues.add(
              MemberImportIssue(
                row: item.row.sourceRow,
                message: _errorText(error),
                suggestion:
                    'صحح البيانات أو الاتصال ثم اختر «إعادة محاولة الفاشل»',
                sourceValues: item.row.toCsvValues(),
                importRow: item.row,
              ),
            );
          }
        }
      }
      report();
    }

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        await flushPendingCreates();
        failedRows.addAll(rows.skip(rowIndex));
        break;
      }
      report(currentRow: row.sourceRow);

      final duplicate = duplicatesByRow[row.sourceRow];
      final duplicateAction =
          duplicateActions[row.sourceRow] ?? MemberImportDuplicateAction.skip;
      if (duplicate != null &&
          duplicateAction == MemberImportDuplicateAction.skip) {
        skippedMembers++;
        processed++;
        report();
        continue;
      }

      try {
        final meetingKey = MemberExcelService._normalize(row.meetingName);
        var resolvedMeetingId = row.meetingId ?? meetingIdsByName[meetingKey];
        if (resolvedMeetingId == null) {
          final destinationError = failedDestinations['meeting:$meetingKey'];
          if (destinationError != null) throw destinationError;
          try {
            final result = await repository.createMeeting(
              name: row.meetingName,
              nameAr: row.meetingName,
              kind: plannedMeetingKinds[meetingKey] ?? MeetingKind.normal,
              weekday: normalizedMeetingWeekdays[meetingKey] ?? 5,
            );
            resolvedMeetingId = result.data.id;
            meetingIdsByName[meetingKey] = resolvedMeetingId;
            createdMeetings++;
            createdMeetingNamesById[resolvedMeetingId] = row.meetingName;
            allSyncedToServer = allSyncedToServer && result.syncedToServer;
          } catch (error) {
            failedDestinations['meeting:$meetingKey'] = error;
            rethrow;
          }
        }

        String? resolvedClassId = row.sundaySchoolClassId;
        if (row.scope == MemberScope.sundaySchoolClass) {
          final className = row.className!;
          final classKey =
              '$meetingKey|'
              '${MemberExcelService._normalize(className)}';
          resolvedClassId ??= classIdsByName[classKey];
          if (resolvedClassId == null) {
            final destinationError = failedDestinations['class:$classKey'];
            if (destinationError != null) throw destinationError;
            try {
              final result = await repository.createSundaySchoolClass(
                meetingId: resolvedMeetingId,
                name: className,
                nameAr: className,
                displayOrder: nextClassOrderByMeeting[resolvedMeetingId] ?? 0,
              );
              resolvedClassId = result.data.id;
              classIdsByName[classKey] = resolvedClassId;
              nextClassOrderByMeeting[resolvedMeetingId] =
                  (nextClassOrderByMeeting[resolvedMeetingId] ?? 0) + 1;
              createdClasses++;
              createdClassNamesById[resolvedClassId] = className;
              createdClassMeetingIds[resolvedClassId] = resolvedMeetingId;
              allSyncedToServer = allSyncedToServer && result.syncedToServer;
            } catch (error) {
              failedDestinations['class:$classKey'] = error;
              rethrow;
            }
          }
        }

        if (duplicate != null &&
            duplicateAction == MemberImportDuplicateAction.update) {
          final existing = duplicate.existingMember;
          final updated = await repository.updateMember(
            id: existing.id,
            fullName: row.fullName,
            scope: row.scope,
            sundaySchoolClassId: resolvedClassId,
            meetingId: row.scope == MemberScope.meeting
                ? resolvedMeetingId
                : null,
            phone: row.phone ?? existing.phone,
            parentName: row.parentName ?? existing.parentName,
            parentPhone: row.parentPhone ?? existing.parentPhone,
            code: row.code ?? existing.code,
            birthDate: row.birthDate ?? existing.birthDate,
            isActive: row.isActive,
            notes: existing.notes,
          );
          allSyncedToServer = allSyncedToServer && updated.syncedToServer;
          updatedMembers++;
          updatedPreviousVersions.add(existing);
          markDestinationSuccess(row, resolvedMeetingId, resolvedClassId);
          imported++;
        } else {
          pendingCreates.add(
            _PendingMemberCreate(
              row: row,
              meetingId: resolvedMeetingId,
              classId: resolvedClassId,
              draft: MemberCreateDraft(
                fullName: row.fullName,
                scope: row.scope,
                sundaySchoolClassId: resolvedClassId,
                meetingId: row.scope == MemberScope.meeting
                    ? resolvedMeetingId
                    : null,
                phone: row.phone,
                parentName: row.parentName,
                parentPhone: row.parentPhone,
                code:
                    duplicate != null &&
                        duplicateAction ==
                            MemberImportDuplicateAction.createNew &&
                        duplicate.codeMatched
                    ? null
                    : row.code,
                birthDate: row.birthDate,
              ),
            ),
          );
        }
      } catch (error) {
        failedRows.add(row);
        issues.add(
          MemberImportIssue(
            row: row.sourceRow,
            message: _errorText(error),
            suggestion: 'صحح البيانات أو الاتصال ثم اختر «إعادة محاولة الفاشل»',
            sourceValues: row.toCsvValues(),
            importRow: row,
          ),
        );
      }
      processed++;
      report();
      if (pendingCreates.length >= batchSize) await flushPendingCreates();
    }
    await flushPendingCreates();

    final removedClassIds = <String>{};
    final removedMeetingIds = <String>{};
    for (final entry in createdClassNamesById.entries) {
      if (successfulClassIds.contains(entry.key)) continue;
      try {
        final members = await repository.getClassMembers(entry.key);
        if (members.isNotEmpty) continue;
        final synced = await repository.deleteSundaySchoolClass(entry.key);
        allSyncedToServer = allSyncedToServer && synced;
        removedEmptyClasses++;
        removedClassIds.add(entry.key);
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message:
                'تعذر تنظيف الفصل الفارغ «${entry.value}»: '
                '${_errorText(error)}',
            suggestion: 'راجع الفصل واحذفه يدويًا إذا ظل فارغًا',
          ),
        );
      }
    }

    for (final entry in createdMeetingNamesById.entries) {
      final hasSuccessfulClass = createdClassMeetingIds.entries.any(
        (classEntry) =>
            classEntry.value == entry.key &&
            successfulClassIds.contains(classEntry.key),
      );
      if (successfulMeetingIds.contains(entry.key) || hasSuccessfulClass) {
        continue;
      }
      try {
        final directMembers = await repository.getMeetingMembers(entry.key);
        final classes = await repository.getAllSundaySchoolClasses();
        final hasClasses = classes.any((item) => item.meetingId == entry.key);
        if (directMembers.isNotEmpty || hasClasses) continue;
        final synced = await repository.deleteMeeting(entry.key);
        allSyncedToServer = allSyncedToServer && synced;
        removedEmptyMeetings++;
        removedMeetingIds.add(entry.key);
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message:
                'تعذر تنظيف الاجتماع الفارغ «${entry.value}»: '
                '${_errorText(error)}',
            suggestion: 'راجع الاجتماع واحذفه يدويًا إذا ظل فارغًا',
          ),
        );
      }
    }

    return MemberImportSaveResult(
      imported: imported,
      createdMembers: createdMembers,
      updatedMembers: updatedMembers,
      skippedMembers: skippedMembers,
      createdMeetings: createdMeetings - removedEmptyMeetings,
      createdClasses: createdClasses - removedEmptyClasses,
      removedEmptyMeetings: removedEmptyMeetings,
      removedEmptyClasses: removedEmptyClasses,
      savedOffline: !allSyncedToServer,
      cancelled: cancelled,
      issues: issues,
      failedRows: failedRows,
      createdMemberIds: createdMemberIds,
      updatedMemberPreviousVersions: updatedPreviousVersions,
      createdMeetingIds: [
        for (final id in createdMeetingNamesById.keys)
          if (!removedMeetingIds.contains(id)) id,
      ],
      createdClassIds: [
        for (final id in createdClassNamesById.keys)
          if (!removedClassIds.contains(id)) id,
      ],
    );
  }

  /// Reverts a finished import: deletes members it created, restores members
  /// it updated, then removes meetings/classes it created if they are empty.
  Future<MemberImportUndoResult> undoImport({
    required DatabaseRepository repository,
    required List<String> createdMemberIds,
    required List<MemberEntity> updatedMemberPreviousVersions,
    required List<String> createdClassIds,
    required List<String> createdMeetingIds,
    void Function(int done, int total)? onProgress,
  }) async {
    var removedMembers = 0;
    var restoredMembers = 0;
    var removedClasses = 0;
    var removedMeetings = 0;
    final issues = <MemberImportIssue>[];
    final total =
        createdMemberIds.length +
        updatedMemberPreviousVersions.length +
        createdClassIds.length +
        createdMeetingIds.length;
    var done = 0;
    void step() => onProgress?.call(++done, total);

    for (final id in createdMemberIds) {
      try {
        await repository.deleteMember(id);
        removedMembers++;
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message: 'تعذر حذف عضو أنشأه الاستيراد: ${_errorText(error)}',
            suggestion: 'احذف العضو يدويًا من قائمة الأعضاء',
          ),
        );
      }
      step();
    }

    for (final previous in updatedMemberPreviousVersions) {
      try {
        await repository.updateMember(
          id: previous.id,
          fullName: previous.fullName,
          scope: previous.scope,
          sundaySchoolClassId: previous.sundaySchoolClassId,
          meetingId: previous.meetingId,
          phone: previous.phone,
          parentName: previous.parentName,
          parentPhone: previous.parentPhone,
          code: previous.code,
          birthDate: previous.birthDate,
          isActive: previous.isActive,
          notes: previous.notes,
        );
        restoredMembers++;
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message:
                'تعذر استرجاع بيانات «${previous.fullName}»: '
                '${_errorText(error)}',
            suggestion: 'راجع بيانات العضو وصححها يدويًا',
          ),
        );
      }
      step();
    }

    for (final id in createdClassIds) {
      try {
        final members = await repository.getClassMembers(id);
        if (members.isEmpty) {
          await repository.deleteSundaySchoolClass(id);
          removedClasses++;
        } else {
          issues.add(
            const MemberImportIssue(
              row: 0,
              message: 'فصل أنشأه الاستيراد لم يعد فارغًا فلم يُحذف',
              suggestion: 'راجع الفصل واحذفه يدويًا إذا لزم',
            ),
          );
        }
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message: 'تعذر حذف فصل أنشأه الاستيراد: ${_errorText(error)}',
            suggestion: 'احذف الفصل يدويًا إذا ظل فارغًا',
          ),
        );
      }
      step();
    }

    for (final id in createdMeetingIds) {
      try {
        final directMembers = await repository.getMeetingMembers(id);
        final classes = await repository.getAllSundaySchoolClasses();
        final hasClasses = classes.any((item) => item.meetingId == id);
        if (directMembers.isEmpty && !hasClasses) {
          await repository.deleteMeeting(id);
          removedMeetings++;
        } else {
          issues.add(
            const MemberImportIssue(
              row: 0,
              message: 'اجتماع أنشأه الاستيراد لم يعد فارغًا فلم يُحذف',
              suggestion: 'راجع الاجتماع واحذفه يدويًا إذا لزم',
            ),
          );
        }
      } catch (error) {
        issues.add(
          MemberImportIssue(
            row: 0,
            message: 'تعذر حذف اجتماع أنشأه الاستيراد: ${_errorText(error)}',
            suggestion: 'احذف الاجتماع يدويًا إذا ظل فارغًا',
          ),
        );
      }
      step();
    }

    return MemberImportUndoResult(
      removedMembers: removedMembers,
      restoredMembers: restoredMembers,
      removedMeetings: removedMeetings,
      removedClasses: removedClasses,
      issues: issues,
    );
  }

  static String _errorText(Object error) => arabicErrorText(error);
}

class _PendingMemberCreate {
  final MemberImportRow row;
  final MemberCreateDraft draft;
  final String meetingId;
  final String? classId;

  const _PendingMemberCreate({
    required this.row,
    required this.draft,
    required this.meetingId,
    required this.classId,
  });
}

class MemberExcelService {
  static const membersSheetName = 'الأعضاء';

  /// Parses an import file off the UI thread. On platforms without isolates
  /// (web) this falls back to running synchronously.
  static Future<MemberImportParseResult> parseAsync(
    MemberImportParseRequest request,
  ) {
    return compute(_parseMemberImportInBackground, request);
  }

  /// Builds an Excel error report that reuses the members sheet layout, so
  /// the user can fix the rows in place and re-import the same file.
  Uint8List buildIssuesWorkbook(List<MemberImportIssue> issues) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) workbook.rename(defaultSheet, membersSheetName);
    final sheet = workbook[membersSheetName]..isRTL = true;

    final headers = [
      ...memberExcelHeaders,
      'رقم الصف الأصلي',
      'سبب الخطأ',
      'طريقة التصحيح',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#B91C1C'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (var column = 0; column < headers.length; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          headerStyle;
      sheet.setColumnWidth(
        column,
        column >= memberExcelHeaders.length ? 35 : 20,
      );
    }

    for (final issue in issues) {
      final values = issue.sourceValues.isNotEmpty
          ? issue.sourceValues
          : (issue.importRow?.toCsvValues() ?? const <String>[]);
      sheet.appendRow([
        for (var index = 0; index < memberExcelHeaders.length; index++)
          TextCellValue(index < values.length ? values[index] : ''),
        TextCellValue(issue.row == 0 ? '' : issue.row.toString()),
        TextCellValue(issue.message),
        TextCellValue(issue.suggestion),
      ]);
    }

    final encoded = workbook.encode();
    if (encoded == null) throw StateError('تعذر إنشاء ملف الأخطاء');
    return Uint8List.fromList(encoded);
  }

  Uint8List buildTemplate({
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
  }) {
    return _buildWorkbook(
      members: const [],
      meetings: meetings,
      classes: classes,
      includeInstructions: true,
    );
  }

  Uint8List exportMembers({
    required List<MemberEntity> members,
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
  }) {
    return _buildWorkbook(
      members: members,
      meetings: meetings,
      classes: classes,
      includeInstructions: true,
    );
  }

  MemberImportParseResult parseImport({
    required Uint8List bytes,
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
    required List<MemberEntity> existingMembers,
  }) {
    late final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } catch (_) {
      return const MemberImportParseResult(
        validRows: [],
        issues: [MemberImportIssue(row: 0, message: 'الملف ليس Excel صالحًا')],
      );
    }

    final sheet =
        workbook.tables[membersSheetName] ??
        (workbook.tables.isEmpty ? null : workbook.tables.values.first);
    if (sheet == null || sheet.rows.isEmpty) {
      return const MemberImportParseResult(
        validRows: [],
        issues: [MemberImportIssue(row: 0, message: 'شيت الأعضاء فارغ')],
      );
    }

    return _parseRows(
      rows: sheet.rows
          .map((row) => row.map(_cellText).toList(growable: false))
          .toList(growable: false),
      meetings: meetings,
      classes: classes,
      existingMembers: existingMembers,
      emptyMessage: 'شيت الأعضاء فارغ',
    );
  }

  MemberImportParseResult parseCsvImport({
    required Uint8List bytes,
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
    required List<MemberEntity> existingMembers,
  }) {
    try {
      var content = utf8.decode(bytes);
      if (content.startsWith('\uFEFF')) content = content.substring(1);
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final firstLine = content.split('\n').firstOrNull ?? '';
      final delimiter = _detectCsvDelimiter(firstLine);
      final decoded = CsvToListConverter(
        fieldDelimiter: delimiter,
        eol: '\n',
        shouldParseNumbers: false,
        allowInvalid: false,
        convertEmptyTo: '',
      ).convert(content);
      return _parseRows(
        rows: decoded
            .map(
              (row) => row
                  .map((value) => value?.toString() ?? '')
                  .toList(growable: false),
            )
            .toList(growable: false),
        meetings: meetings,
        classes: classes,
        existingMembers: existingMembers,
        emptyMessage: 'ملف CSV فارغ',
      );
    } catch (_) {
      return const MemberImportParseResult(
        validRows: [],
        issues: [
          MemberImportIssue(
            row: 0,
            message: 'الملف ليس CSV صالحًا أو ليس محفوظًا بترميز UTF-8',
          ),
        ],
      );
    }
  }

  MemberImportParseResult _parseRows({
    required List<List<String>> rows,
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
    required List<MemberEntity> existingMembers,
    required String emptyMessage,
  }) {
    if (rows.isEmpty ||
        rows.every((row) => row.every((value) => value.trim().isEmpty))) {
      return MemberImportParseResult(
        validRows: const [],
        issues: [MemberImportIssue(row: 0, message: emptyMessage)],
      );
    }

    final issues = <MemberImportIssue>[];
    final warnings = <MemberImportIssue>[];
    final validRows = <MemberImportRow>[];
    final duplicates = <MemberImportDuplicate>[];

    final headerIndexes = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      final header = _normalizeHeader(rows.first[index]);
      if (header.isNotEmpty) headerIndexes[header] = index;
    }
    final requiredHeaders = ['الاسم الكامل', 'نوع التبعية', 'الاجتماع'];
    final missing = requiredHeaders
        .where((header) => !headerIndexes.containsKey(header))
        .toList();
    if (missing.isNotEmpty) {
      return MemberImportParseResult(
        validRows: const [],
        issues: [
          MemberImportIssue(
            row: 1,
            message: 'أعمدة مطلوبة غير موجودة: ${missing.join('، ')}',
          ),
        ],
      );
    }

    final meetingsByName = <String, MeetingEntity>{};
    for (final meeting in meetings) {
      meetingsByName[_normalize(meeting.nameAr)] = meeting;
      meetingsByName[_normalize(meeting.name)] = meeting;
    }
    final existingByCode = <String, List<MemberEntity>>{};
    final existingByPhone = <String, List<MemberEntity>>{};
    for (final member in existingMembers) {
      final code = _normalize(member.code ?? '');
      if (code.isNotEmpty) {
        existingByCode.putIfAbsent(code, () => []).add(member);
      }
      final phone = _normalizePhone(member.phone);
      if (phone.isNotEmpty) {
        existingByPhone.putIfAbsent(phone, () => []).add(member);
      }
    }
    final incomingCodes = <String>{};
    final incomingIdentities = <String>{};
    final incomingPhoneRows = <String, int>{};

    String valueAt(List<String> row, dynamic headers) {
      final headerList = headers is List<String>
          ? headers
          : [headers.toString()];
      for (final header in headerList) {
        final norm = _normalizeHeader(header);
        final index = headerIndexes[norm];
        if (index != null && index < row.length) {
          final text = row[index].trim();
          if (text.isNotEmpty) return text;
        }
      }
      return '';
    }

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final sourceRow = rowIndex + 1;
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      final fullName = valueAt(row, ['الاسم الكامل', 'الاسم']);
      final scopeText = _normalize(
        valueAt(row, ['نوع التبعية', 'التبعية', 'النوع']),
      );
      final meetingText = valueAt(row, ['الاجتماع', 'اسم الاجتماع']);
      final classText = valueAt(row, ['الفصل', 'اسم الفصل']);
      final phone = _emptyToNull(
        valueAt(row, [
          'رقم هاتف العضو',
          'رقم التليفون',
          'هاتف العضو',
          'الهاتف',
          'الموبايل',
        ]),
      );
      final parentName = _emptyToNull(
        valueAt(row, ['اسم ولي الأمر', 'ولي الأمر']),
      );
      final parentPhone = _emptyToNull(
        valueAt(row, [
          'هاتف ولي الأمر',
          'موبايل ولي الأمر',
          'تليفون ولي الأمر',
        ]),
      );
      final code = _emptyToNull(
        valueAt(row, ['الكود التعريفي', 'الكود', 'كود']),
      );
      final birthDateText = valueAt(row, [
        'تاريخ الميلاد (yyyy-mm-dd)',
        'تاريخ الميلاد',
        'تاريخ الميلاد yyyy-mm-dd',
        'تاريخ الميلاد YYYY-MM-DD',
      ]);
      final activeText = _normalize(
        valueAt(row, ['نشط (نعم/لا)', 'نشط نعم/لا', 'نشط', 'الحالة']),
      );
      final sourceValues = [
        fullName,
        valueAt(row, ['نوع التبعية', 'التبعية', 'النوع']),
        meetingText,
        classText,
        birthDateText,
        phone ?? '',
        code ?? '',
        parentName ?? '',
        parentPhone ?? '',
        activeText,
      ];

      if (fullName.isEmpty) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'الاسم الكامل مطلوب',
            suggestion: 'اكتب الاسم الكامل للعضو',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      final scope = _parseScope(scopeText);
      if (scope == null) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'نوع التبعية يجب أن يكون «فصل» أو «اجتماع»',
            suggestion: 'اكتب فصل أو اجتماع فقط في نوع التبعية',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      final meeting = meetingsByName[_normalize(meetingText)];
      if (meetingText.isEmpty) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'اسم الاجتماع مطلوب',
            suggestion: 'اكتب اسم الاجتماع المطلوب أو اسم اجتماع جديد',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      SundaySchoolClassEntity? classEntity;
      if (scope == MemberScope.sundaySchoolClass) {
        if (classText.isEmpty) {
          issues.add(
            MemberImportIssue(
              row: sourceRow,
              message: 'اسم الفصل مطلوب لنوع التبعية «فصل»',
              suggestion: 'اكتب اسم الفصل أو غيّر نوع التبعية إلى اجتماع',
              sourceValues: sourceValues,
            ),
          );
          continue;
        }
        if (meeting != null && meeting.kind != MeetingKind.sundaySchool) {
          issues.add(
            MemberImportIssue(
              row: sourceRow,
              message: 'لا يمكن إنشاء فصل داخل الاجتماع المباشر «$meetingText»',
              suggestion: 'اختر اجتماع مدارس أحد أو استخدم اسم اجتماع جديد',
              sourceValues: sourceValues,
            ),
          );
          continue;
        }
        if (meeting != null) {
          classEntity = classes
              .where(
                (item) =>
                    item.meetingId == meeting.id &&
                    (_normalize(item.nameAr) == _normalize(classText) ||
                        _normalize(item.name) == _normalize(classText)),
              )
              .firstOrNull;
        }
      }

      DateTime? birthDate;
      if (birthDateText.isNotEmpty) {
        birthDate = _parseDate(birthDateText);
        if (birthDate == null) {
          issues.add(
            MemberImportIssue(
              row: sourceRow,
              message: 'تاريخ الميلاد غير صحيح؛ استخدم YYYY-MM-DD',
              suggestion: 'مثال صحيح: 2012-08-25',
              sourceValues: sourceValues,
            ),
          );
          continue;
        }
      }

      final normalizedCode = _normalize(code ?? '');
      if (normalizedCode.isNotEmpty && !incomingCodes.add(normalizedCode)) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'الكود «$code» مكرر داخل الملف',
            suggestion: 'استخدم كودًا مختلفًا لكل صف داخل الملف',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      final targetId = scope == MemberScope.sundaySchoolClass
          ? (classEntity?.id ??
                'new-class:${_normalize(meetingText)}:${_normalize(classText)}')
          : (meeting?.id ?? 'new-meeting:${_normalize(meetingText)}');
      final identity = '${_normalize(fullName)}|$targetId';
      if (!incomingIdentities.add(identity)) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'العضو مكرر في نفس الوجهة داخل الملف',
            suggestion: 'احذف أحد الصفين المكررين من الملف',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      final importRow = MemberImportRow(
        sourceRow: sourceRow,
        fullName: fullName,
        scope: scope,
        meetingName: meetingText,
        className: scope == MemberScope.sundaySchoolClass ? classText : null,
        sundaySchoolClassId: classEntity?.id,
        meetingId: meeting?.id,
        phone: phone,
        parentName: parentName,
        parentPhone: parentPhone,
        code: code,
        birthDate: birthDate,
        isActive:
            activeText.isEmpty ||
            const {'نعم', 'yes', 'true', '1', 'نشط'}.contains(activeText),
      );

      final candidateReasons = <String, Set<String>>{};
      final candidatesById = <String, MemberEntity>{};
      void addCandidates(Iterable<MemberEntity> members, String reason) {
        for (final member in members) {
          candidatesById[member.id] = member;
          candidateReasons.putIfAbsent(member.id, () => <String>{}).add(reason);
        }
      }

      if (normalizedCode.isNotEmpty) {
        addCandidates(existingByCode[normalizedCode] ?? const [], 'الكود');
      }
      final normalizedPhone = _normalizePhone(phone);
      if (normalizedPhone.isNotEmpty) {
        addCandidates(existingByPhone[normalizedPhone] ?? const [], 'الهاتف');
      }
      if (meeting != null) {
        addCandidates(
          existingMembers.where(
            (member) =>
                _normalize(member.fullName) == _normalize(fullName) &&
                (scope == MemberScope.sundaySchoolClass
                    ? classEntity != null &&
                          member.sundaySchoolClassId == classEntity.id
                    : member.meetingId == meeting.id),
          ),
          'الاسم ونفس التبعية',
        );
      }

      if (candidatesById.length > 1) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'بيانات الصف تطابق أكثر من عضو موجود',
            suggestion: 'وحّد الكود والهاتف مع العضو الصحيح ثم أعد الاستيراد',
            sourceValues: sourceValues,
          ),
        );
        continue;
      }

      for (final (label, value) in [
        ('رقم هاتف العضو', phone),
        ('هاتف ولي الأمر', parentPhone),
      ]) {
        if (value == null || _looksLikeValidPhone(value)) continue;
        warnings.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'تحذير: $label «$value» يبدو غير صحيح',
            suggestion: 'راجع الرقم؛ سيُستورد الصف كما هو',
            sourceValues: sourceValues,
          ),
        );
      }
      if (normalizedPhone.isNotEmpty) {
        final firstRow = incomingPhoneRows[normalizedPhone];
        if (firstRow == null) {
          incomingPhoneRows[normalizedPhone] = sourceRow;
        } else {
          warnings.add(
            MemberImportIssue(
              row: sourceRow,
              message:
                  'تحذير: رقم هاتف العضو «$phone» مكرر مع الصف $firstRow داخل الملف',
              suggestion: 'تأكد أن الصفين لعضوين مختلفين فعلًا',
              sourceValues: sourceValues,
            ),
          );
        }
      }

      validRows.add(importRow);
      if (candidatesById.length == 1) {
        final existing = candidatesById.values.single;
        duplicates.add(
          MemberImportDuplicate(
            row: importRow,
            existingMember: existing,
            matchedBy: candidateReasons[existing.id]!.toList(growable: false),
          ),
        );
      }
    }

    final newMeetingScopes = <String, Set<MemberScope>>{};
    for (final row in validRows.where((row) => row.meetingId == null)) {
      newMeetingScopes
          .putIfAbsent(_normalize(row.meetingName), () => <MemberScope>{})
          .add(row.scope);
    }
    final conflictingMeetings = newMeetingScopes.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => entry.key)
        .toSet();
    if (conflictingMeetings.isNotEmpty) {
      final conflictedRows = validRows
          .where(
            (row) =>
                row.meetingId == null &&
                conflictingMeetings.contains(_normalize(row.meetingName)),
          )
          .toList();
      final conflictedSourceRows = conflictedRows
          .map((row) => row.sourceRow)
          .toSet();
      validRows.removeWhere(
        (row) =>
            row.meetingId == null &&
            conflictingMeetings.contains(_normalize(row.meetingName)),
      );
      issues.addAll(
        conflictedRows.map(
          (row) => MemberImportIssue(
            row: row.sourceRow,
            message:
                'الاجتماع الجديد «${row.meetingName}» مستخدم كاجتماع مباشر ومدارس أحد في نفس الملف؛ استخدم اسمين مختلفين',
            suggestion: 'استخدم اسمًا مختلفًا للاجتماع المباشر عن مدارس الأحد',
            sourceValues: row.toCsvValues(),
          ),
        ),
      );
      duplicates.removeWhere(
        (duplicate) => conflictedSourceRows.contains(duplicate.row.sourceRow),
      );
      warnings.removeWhere(
        (warning) => conflictedSourceRows.contains(warning.row),
      );
    }

    return MemberImportParseResult(
      validRows: validRows,
      issues: issues,
      warnings: warnings,
      duplicates: duplicates,
    );
  }

  static bool _looksLikeValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && digits.length <= 15;
  }

  static String _detectCsvDelimiter(String firstLine) {
    var commas = 0;
    var semicolons = 0;
    var insideQuotes = false;
    for (var index = 0; index < firstLine.length; index++) {
      final char = firstLine[index];
      if (char == '"') {
        if (insideQuotes &&
            index + 1 < firstLine.length &&
            firstLine[index + 1] == '"') {
          index++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (!insideQuotes && char == ',') {
        commas++;
      } else if (!insideQuotes && char == ';') {
        semicolons++;
      }
    }
    return semicolons > commas ? ';' : ',';
  }

  Uint8List _buildWorkbook({
    required List<MemberEntity> members,
    required List<MeetingEntity> meetings,
    required List<SundaySchoolClassEntity> classes,
    required bool includeInstructions,
  }) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null) workbook.rename(defaultSheet, membersSheetName);
    final sheet = workbook[membersSheetName]..isRTL = true;

    sheet.appendRow(
      memberExcelHeaders.map((header) => TextCellValue(header)).toList(),
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#4338CA'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
    for (var column = 0; column < memberExcelHeaders.length; column++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
              )
              .cellStyle =
          headerStyle;
      sheet.setColumnWidth(column, switch (column) {
        0 => 25,
        1 => 16,
        2 || 3 => 22,
        4 || 6 => 18,
        5 => 22,
        _ => 17,
      });
    }

    final meetingById = {for (final meeting in meetings) meeting.id: meeting};
    final classById = {for (final item in classes) item.id: item};
    for (final member in members) {
      final classEntity = classById[member.sundaySchoolClassId];
      final meeting = meetingById[classEntity?.meetingId ?? member.meetingId];
      sheet.appendRow([
        TextCellValue(member.fullName),
        TextCellValue(
          member.scope == MemberScope.sundaySchoolClass ? 'فصل' : 'اجتماع',
        ),
        TextCellValue(meeting?.nameAr ?? ''),
        TextCellValue(classEntity?.nameAr ?? ''),
        TextCellValue(_formatDate(member.birthDate)),
        TextCellValue(member.phone ?? ''),
        TextCellValue(member.code ?? ''),
        TextCellValue(member.parentName ?? ''),
        TextCellValue(member.parentPhone ?? ''),
        TextCellValue(member.isActive ? 'نعم' : 'لا'),
      ]);
    }

    if (includeInstructions) {
      _addValuesSheet(workbook, meetings, classes);
      _addInstructionsSheet(workbook);
    }

    final encoded = workbook.encode();
    if (encoded == null) throw StateError('تعذر إنشاء ملف Excel');
    return Uint8List.fromList(encoded);
  }

  void _addValuesSheet(
    Excel workbook,
    List<MeetingEntity> meetings,
    List<SundaySchoolClassEntity> classes,
  ) {
    final sheet = workbook['القيم المتاحة']..isRTL = true;
    sheet.appendRow([
      TextCellValue('الاجتماع'),
      TextCellValue('نوع التبعية'),
      TextCellValue('الفصل'),
    ]);
    for (final meeting in meetings.where((item) => item.isActive)) {
      final meetingClasses = classes.where(
        (item) => item.meetingId == meeting.id && item.isActive,
      );
      if (meeting.kind != MeetingKind.sundaySchool) {
        sheet.appendRow([
          TextCellValue(meeting.nameAr),
          TextCellValue('اجتماع'),
          TextCellValue(''),
        ]);
      }
      for (final classEntity in meetingClasses) {
        sheet.appendRow([
          TextCellValue(meeting.nameAr),
          TextCellValue('فصل'),
          TextCellValue(classEntity.nameAr),
        ]);
      }
    }
    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 25);
  }

  void _addInstructionsSheet(Excel workbook) {
    final sheet = workbook['تعليمات']..isRTL = true;
    final instructions = [
      'اكتب البيانات داخل شيت «الأعضاء» فقط ولا تغير أسماء الأعمدة.',
      'نوع التبعية يكون «فصل» أو «اجتماع».',
      'انسخ أسماء الاجتماعات والفصول من شيت «القيم المتاحة».',
      'إذا كان الاجتماع أو الفصل غير موجود، سيُنشأ تلقائيًا بعد ظهوره في المعاينة.',
      'قبل الاستيراد ستختار يوم كل اجتماع جديد من شاشة المعاينة.',
      'لنوع «فصل»: الاجتماع والفصل مطلوبان. لنوع «اجتماع»: اترك الفصل فارغًا.',
      'تاريخ الميلاد اختياري ويكتب بالشكل 2012-08-25.',
      'الهاتف والكود اختياريان. يفضل كتابة الهاتف كنص للحفاظ على الصفر الأول.',
      'نشط: نعم أو لا. إذا تركت الخانة فارغة سيُنشأ العضو نشطًا.',
      'ستظهر معاينة بالأخطاء قبل حفظ أي أعضاء.',
      '',
      'مثال: مينا سمير | فصل | اجتماع مدارس الأحد | أولى إعدادي | 01000000000',
    ];
    for (final instruction in instructions) {
      sheet.appendRow([TextCellValue(instruction)]);
    }
    sheet.setColumnWidth(0, 95);
  }

  static String _cellText(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue() => value.toString(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'نعم' : 'لا',
      DateCellValue() => _formatDate(value.asDateTimeLocal()),
      DateTimeCellValue() => _formatDate(value.asDateTimeLocal()),
      TimeCellValue() => value.asDuration().toString(),
      FormulaCellValue() => value.formula,
    };
  }

  static MemberScope? _parseScope(String value) {
    if (const {
      'فصل',
      'مدارس الاحد',
      'class',
      'sunday_school_class',
    }.contains(value)) {
      return MemberScope.sundaySchoolClass;
    }
    if (const {'اجتماع', 'meeting'}.contains(value)) {
      return MemberScope.meeting;
    }
    return null;
  }

  static DateTime? _parseDate(String value) {
    final normalized = value.trim().replaceAll('/', '-');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct;
    final parts = normalized.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _normalizeHeader(String value) {
    return _normalize(
      value
          .replaceAll('*', '')
          .replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ')
          .trim(),
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizePhone(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'[^0-9+]'), '').replaceFirst('+20', '0');
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
