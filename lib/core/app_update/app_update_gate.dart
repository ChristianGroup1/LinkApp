import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkForUpdate());
    });
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await Supabase.instance.client.functions.invoke(
        'app-version',
        method: HttpMethod.get,
      );
      final data = response.data;
      if (data is! Map) return;

      final minimumVersion = data['minimum_version']?.toString();
      final updateUrl = defaultTargetPlatform == TargetPlatform.android
          ? data['android_url']?.toString()
          : data['ios_url']?.toString();
      if (minimumVersion == null || updateUrl == null) return;
      if (_compareVersions(packageInfo.version, minimumVersion) >= 0) return;
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('يتوفر تحديث جديد'),
          content: const Text(
            'حدّث تطبيق LinkApp للحصول على آخر الإصلاحات ومتابعة استخدام التطبيق.',
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لاحقاً'),
            ),
            FilledButton(
              onPressed: () async {
                final uri = Uri.tryParse(updateUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('تحديث التطبيق'),
            ),
          ],
        ),
      );
    } catch (error) {
      // Version checks must not block startup when the device is offline or
      // the update endpoint is temporarily unavailable.
      debugPrint('[AppUpdate] Update check skipped: $error');
    }
  }

  int _compareVersions(String current, String minimum) {
    final currentParts = current.split('.');
    final minimumParts = minimum.split('.');
    final count = currentParts.length > minimumParts.length
        ? currentParts.length
        : minimumParts.length;

    for (var index = 0; index < count; index++) {
      final currentPart = index < currentParts.length
          ? int.tryParse(currentParts[index]) ?? 0
          : 0;
      final minimumPart = index < minimumParts.length
          ? int.tryParse(minimumParts[index]) ?? 0
          : 0;
      if (currentPart != minimumPart) {
        return currentPart.compareTo(minimumPart);
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
