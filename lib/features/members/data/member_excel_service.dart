import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../../data/models/models.dart';

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
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    this.birthDate,
    required this.isActive,
  });
}

class MemberImportIssue {
  final int row;
  final String message;

  const MemberImportIssue({required this.row, required this.message});
}

class MemberImportParseResult {
  final List<MemberImportRow> validRows;
  final List<MemberImportIssue> issues;

  const MemberImportParseResult({
    required this.validRows,
    required this.issues,
  });
}

class MemberExcelService {
  static const membersSheetName = 'الأعضاء';

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
    final issues = <MemberImportIssue>[];
    final validRows = <MemberImportRow>[];
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

    final headerIndexes = <String, int>{};
    for (var index = 0; index < sheet.rows.first.length; index++) {
      final header = _normalizeHeader(_cellText(sheet.rows.first[index]));
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
    final existingCodes = existingMembers
        .map((member) => _normalize(member.code ?? ''))
        .where((code) => code.isNotEmpty)
        .toSet();
    final incomingCodes = <String>{};
    final incomingIdentities = <String>{};

    String valueAt(List<Data?> row, dynamic headers) {
      final headerList =
          headers is List<String> ? headers : [headers.toString()];
      for (final header in headerList) {
        final norm = _normalizeHeader(header);
        final index = headerIndexes[norm];
        if (index != null && index < row.length) {
          final text = _cellText(row[index]).trim();
          if (text.isNotEmpty) return text;
        }
      }
      return '';
    }

    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final sourceRow = rowIndex + 1;
      if (row.every((cell) => _cellText(cell).trim().isEmpty)) continue;

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

      if (fullName.isEmpty) {
        issues.add(
          MemberImportIssue(row: sourceRow, message: 'الاسم الكامل مطلوب'),
        );
        continue;
      }

      final scope = _parseScope(scopeText);
      if (scope == null) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'نوع التبعية يجب أن يكون «فصل» أو «اجتماع»',
          ),
        );
        continue;
      }

      final meeting = meetingsByName[_normalize(meetingText)];
      if (meeting == null) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'الاجتماع «$meetingText» غير موجود',
          ),
        );
        continue;
      }

      SundaySchoolClassEntity? classEntity;
      if (scope == MemberScope.sundaySchoolClass) {
        classEntity = classes
            .where(
              (item) =>
                  item.meetingId == meeting.id &&
                  (_normalize(item.nameAr) == _normalize(classText) ||
                      _normalize(item.name) == _normalize(classText)),
            )
            .firstOrNull;
        if (classText.isEmpty || classEntity == null) {
          issues.add(
            MemberImportIssue(
              row: sourceRow,
              message: 'الفصل «$classText» غير موجود داخل $meetingText',
            ),
          );
          continue;
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
            ),
          );
          continue;
        }
      }

      final normalizedCode = _normalize(code ?? '');
      if (normalizedCode.isNotEmpty &&
          (existingCodes.contains(normalizedCode) ||
              !incomingCodes.add(normalizedCode))) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'الكود «$code» مستخدم من قبل أو مكرر في الملف',
          ),
        );
        continue;
      }

      final targetId = classEntity?.id ?? meeting.id;
      final identity = '${_normalize(fullName)}|$targetId';
      if (!incomingIdentities.add(identity)) {
        issues.add(
          MemberImportIssue(
            row: sourceRow,
            message: 'العضو مكرر في نفس الوجهة داخل الملف',
          ),
        );
        continue;
      }

      validRows.add(
        MemberImportRow(
          sourceRow: sourceRow,
          fullName: fullName,
          scope: scope,
          sundaySchoolClassId: classEntity?.id,
          meetingId: scope == MemberScope.meeting ? meeting.id : null,
          phone: phone,
          parentName: parentName,
          parentPhone: parentPhone,
          code: code,
          birthDate: birthDate,
          isActive:
              activeText.isEmpty ||
              const {'نعم', 'yes', 'true', '1', 'نشط'}.contains(activeText),
        ),
      );
    }

    return MemberImportParseResult(validRows: validRows, issues: issues);
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

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
