import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Minimal, privacy-conscious product analytics for the owner dashboard.
///
/// Events are recorded only for authenticated users. No device identifiers,
/// location, contact data, or free-form user content is collected.
class AppAnalyticsService {
  AppAnalyticsService._();

  static bool _appOpenRecorded = false;
  static bool _signInRecorded = false;
  static Future<bool>? _appOpenInFlight;
  static Future<bool>? _signInInFlight;
  static final Map<String, Future<String?>> _churchIdReadsInFlight = {};

  static Future<void> trackAppOpen() async {
    if (_appOpenRecorded) return;
    final active = _appOpenInFlight;
    if (active != null) {
      await active;
      return;
    }

    late final Future<bool> recording;
    recording = _record('app_open').whenComplete(() {
      if (identical(_appOpenInFlight, recording)) _appOpenInFlight = null;
    });
    _appOpenInFlight = recording;
    if (await recording) _appOpenRecorded = true;
  }

  static Future<void> trackSignIn() async {
    if (_signInRecorded) return;
    final active = _signInInFlight;
    if (active != null) {
      await active;
      return;
    }

    late final Future<bool> recording;
    recording = _record('sign_in').whenComplete(() {
      if (identical(_signInInFlight, recording)) _signInInFlight = null;
    });
    _signInInFlight = recording;
    if (await recording) _signInRecorded = true;
  }

  static Future<bool> _record(String eventName) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      final churchId = await _readChurchId(client, user.id);
      if (churchId == null) return false;

      final packageInfo = await PackageInfo.fromPlatform();
      await client.from('app_usage_events').insert({
        'user_id': user.id,
        'church_id': churchId,
        'event_name': eventName,
        'platform': _platformName,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      });
      return true;
    } catch (error) {
      // Analytics must never interrupt login or normal application use. This
      // also keeps older deployments working before the migration is applied.
      debugPrint('[AppAnalytics] Event was not recorded: $error');
      return false;
    }
  }

  static Future<String?> _readChurchId(
    SupabaseClient client,
    String userId,
  ) async {
    final active = _churchIdReadsInFlight[userId];
    if (active != null) return active;

    late final Future<String?> read;
    read = client
        .from('profiles')
        .select('church_id')
        .eq('id', userId)
        .maybeSingle()
        .then((profile) => profile?['church_id'] as String?)
        .whenComplete(() {
          if (identical(_churchIdReadsInFlight[userId], read)) {
            _churchIdReadsInFlight.remove(userId);
          }
        });
    _churchIdReadsInFlight[userId] = read;
    return read;
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
