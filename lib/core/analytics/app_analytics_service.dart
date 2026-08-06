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

  static Future<void> trackAppOpen() async {
    if (_appOpenRecorded) return;
    final saved = await _record('app_open');
    if (saved) _appOpenRecorded = true;
  }

  static Future<void> trackSignIn() async {
    if (_signInRecorded) return;
    final saved = await _record('sign_in');
    if (saved) _signInRecorded = true;
  }

  static Future<bool> _record(String eventName) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return false;

      final profile = await client
          .from('profiles')
          .select('church_id')
          .eq('id', user.id)
          .maybeSingle();
      final churchId = profile?['church_id'] as String?;
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
