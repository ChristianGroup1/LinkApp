import 'package:geolocator/geolocator.dart';

import 'member_location.dart';

class MemberLocationException implements Exception {
  final String message;

  const MemberLocationException(this.message);
}

/// Reads the device location after asking for permission when it is still undecided.
Future<MemberLocation> readCurrentMemberLocation() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const MemberLocationException(
        'فعّل خدمة الموقع في الجهاز ثم أعد المحاولة',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const MemberLocationException('لم يتم السماح بالوصول إلى الموقع');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const MemberLocationException(
        'إذن الموقع مرفوض. فعّله من إعدادات الجهاز ثم أعد المحاولة',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final location = MemberLocation.fromNumbers(
      position.latitude,
      position.longitude,
    );
    if (location == null) {
      throw const MemberLocationException('تعذر قراءة موقع صالح من الجهاز');
    }
    return location;
  } on MemberLocationException {
    rethrow;
  } catch (_) {
    throw const MemberLocationException(
      'تعذر تحديد موقعك الحالي. تحقق من إذن الموقع ثم أعد المحاولة',
    );
  }
}
