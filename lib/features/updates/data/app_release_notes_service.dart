import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppReleaseNote {
  final String version;
  final DateTime? publishedAt;
  final String title;
  final String summary;
  final List<String> changes;

  const AppReleaseNote({
    required this.version,
    required this.publishedAt,
    required this.title,
    required this.summary,
    required this.changes,
  });

  factory AppReleaseNote.fromJson(Map<String, dynamic> json) => AppReleaseNote(
    version: json['version']?.toString() ?? '',
    publishedAt: DateTime.tryParse(json['published_at']?.toString() ?? ''),
    title: json['title']?.toString() ?? 'تحديث جديد',
    summary: json['summary']?.toString() ?? '',
    changes: (json['changes'] as List? ?? const [])
        .map((change) => change.toString())
        .where((change) => change.isNotEmpty)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'published_at': publishedAt?.toIso8601String(),
    'title': title,
    'summary': summary,
    'changes': changes,
  };
}

class AppReleaseNotesService {
  AppReleaseNotesService._();

  static const _cacheKey = 'app_release_notes_cache_v1';

  static Future<List<AppReleaseNote>> load() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'app-version',
        method: HttpMethod.get,
      );
      final data = response.data;
      if (data is! Map || data['updates'] is! List) {
        throw const FormatException('Invalid app update manifest');
      }
      final notes =
          (data['updates'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    AppReleaseNote.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((note) => note.version.isNotEmpty)
              .toList()
            ..sort((a, b) => _compareVersions(b.version, a.version));
      await preferences.setString(
        _cacheKey,
        jsonEncode(notes.map((note) => note.toJson()).toList()),
      );
      return notes;
    } catch (_) {
      final cached = preferences.getString(_cacheKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => AppReleaseNote.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList()
        ..sort((a, b) => _compareVersions(b.version, a.version));
    }
  }

  static int _compareVersions(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    final count = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < count; index++) {
      final leftPart = index < leftParts.length
          ? int.tryParse(leftParts[index]) ?? 0
          : 0;
      final rightPart = index < rightParts.length
          ? int.tryParse(rightParts[index]) ?? 0
          : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }
}
