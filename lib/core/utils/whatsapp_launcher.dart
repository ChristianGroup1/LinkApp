import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

String normalizeWhatsAppNumber(
  String number, {
  String defaultCountryCode = '20',
}) {
  var digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) {
    digits = '$defaultCountryCode${digits.substring(1)}';
  } else if (!digits.startsWith(defaultCountryCode) && digits.length <= 10) {
    digits = '$defaultCountryCode$digits';
  }
  return digits;
}

Future<bool> launchWhatsAppChat({
  String? phone,
  required String message,
}) async {
  final normalizedPhone = phone == null || phone.trim().isEmpty
      ? null
      : normalizeWhatsAppNumber(phone);
  final query = <String, String>{'text': message};
  if (normalizedPhone != null) query['phone'] = normalizedPhone;

  final candidates = normalizedPhone == null
      ? [
          Uri.https('wa.me', '/', query),
          Uri.https('api.whatsapp.com', '/send', query),
        ]
      : [
          Uri.https('wa.me', '/$normalizedPhone', {'text': message}),
          Uri.https('api.whatsapp.com', '/send', query),
        ];

  for (final uri in candidates) {
    try {
      // Avoid canLaunchUrl: Android package visibility can report false even
      // when WhatsApp or a browser can handle the HTTPS URL.
      if (await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      )) {
        return true;
      }
    } catch (_) {}
  }
  return false;
}
