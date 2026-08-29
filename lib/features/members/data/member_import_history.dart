import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MemberImportHistoryEntry {
  final String id;
  final DateTime date;
  final String fileName;
  final int created;
  final int updated;
  final int skipped;
  final int failed;
  final bool cancelled;
  final bool undone;

  const MemberImportHistoryEntry({
    required this.id,
    required this.date,
    required this.fileName,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    this.cancelled = false,
    this.undone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'file_name': fileName,
    'created': created,
    'updated': updated,
    'skipped': skipped,
    'failed': failed,
    'cancelled': cancelled,
    'undone': undone,
  };

  factory MemberImportHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MemberImportHistoryEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      fileName: json['file_name'] as String? ?? '',
      created: json['created'] as int? ?? 0,
      updated: json['updated'] as int? ?? 0,
      skipped: json['skipped'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      cancelled: json['cancelled'] as bool? ?? false,
      undone: json['undone'] as bool? ?? false,
    );
  }
}

/// Keeps the most recent member import runs on the device.
class MemberImportHistoryStore {
  static const _key = 'member_import_history';
  static const _maxEntries = 30;

  Future<List<MemberImportHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return [
        for (final item in decoded)
          MemberImportHistoryEntry.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(MemberImportHistoryEntry entry) async {
    final entries = [entry, ...await load()];
    await _save(entries.take(_maxEntries).toList(growable: false));
  }

  Future<void> _save(List<MemberImportHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final entry in entries) entry.toJson()]),
    );
  }
}
