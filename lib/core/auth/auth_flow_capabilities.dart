import 'package:flutter/foundation.dart';

/// Auth flows that rely on native deep links / email app handoff.
///
/// The PWA keeps day-to-day church management, but password-reset emails and
/// servant invitations stay on the store apps (`io.supabase.link://…`).
bool get supportsNativeAuthDeepLinks => !kIsWeb;

bool get supportsPasswordResetEmail => supportsNativeAuthDeepLinks;

bool get supportsInvitations => supportsNativeAuthDeepLinks;
