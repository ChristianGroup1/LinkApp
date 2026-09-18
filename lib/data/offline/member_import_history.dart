import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One member import run performed on this device.
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

/// Keeps the most recent member import runs of a single church on this device.
///
/// An import log is church data: it names files and record counts that belong to
/// one tenant only. Runs are therefore stored under a per-church key and never
/// under a device-global key, so signing in to a different church on the same
/// device can neither read nor inherit the previous church's log.
class MemberImportHistoryStore {
  /// Every key written by this store starts with this prefix.
  static const keyPrefix = 'member_import_history';

  /// Key used by releases that kept every church under one unscoped list.
  /// Those entries carry no church id, so they are discarded on read instead of
  /// being shown to whichever church happens to open the log next.
  static const legacyKey = keyPrefix;

  static const _maxEntries = 30;

  /// Church whose runs this store reads and writes. A null id — an account that
  /// is not attached to a church — disables the store rather than falling back
  /// to another church's entries.
  final String? churchId;

  const MemberImportHistoryStore({required this.churchId});

  /// Key holding this church's runs, or null when no church is attached.
  String? get storageKey => churchId == null ? null : '${keyPrefix}_$churchId';

  Future<List<MemberImportHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _discardUnscopedEntries(prefs);
    final key = storageKey;
    if (key == null) return const [];
    return _decode(prefs.getString(key));
  }

  Future<void> add(MemberImportHistoryEntry entry) async {
    final key = storageKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await _discardUnscopedEntries(prefs);
    final entries = [entry, ..._decode(prefs.getString(key))];
    await prefs.setString(
      key,
      jsonEncode([for (final item in entries.take(_maxEntries)) item.toJson()]),
    );
  }

  /// Deletes the device-global list older builds wrote, which no church owns.
  ///
  /// Every account that signs in sweeps it here, so the unscoped entries can
  /// never be read back by whichever church opens the log next. Sign-out and
  /// account deletion also drop it, through `OfflineCache.clearAll`, which lists
  /// [keyPrefix] among the values a device must clear before another account
  /// signs in.
  static Future<void> _discardUnscopedEntries(SharedPreferences prefs) async {
    if (prefs.containsKey(legacyKey)) {
      await prefs.remove(legacyKey);
    }
  }

  static List<MemberImportHistoryEntry> _decode(String? raw) {
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
}
