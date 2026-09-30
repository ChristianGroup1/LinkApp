import 'package:flutter/foundation.dart';

/// Auth flows that rely on native deep links / email app handoff.
bool get supportsNativeAuthDeepLinks => !kIsWeb;

// Reset requests from the PWA use its browser callback page. Native requests
// continue using the registered app scheme.
bool get supportsPasswordResetEmail => true;

// Invitation links also have a browser route, so they remain usable from the
// Flutter Web app when the native app is not installed.
bool get supportsInvitations => true;
