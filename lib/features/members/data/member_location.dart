/// Optional map coordinates for a served member.
class MemberLocation {
  final double latitude;
  final double longitude;

  const MemberLocation({required this.latitude, required this.longitude});

  /// Cairo, used when the member has no pin yet and the map needs a center.
  static const defaultLatitude = 30.0444;
  static const defaultLongitude = 31.2357;

  /// Public OSM tile endpoint. Identify the app with [userAgentPackageName].
  static const tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgentPackageName = 'com.linkapp.church';
  static final copyrightUri = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  static MemberLocation? fromNumbers(double? latitude, double? longitude) {
    if (!_isInRange(latitude, longitude)) return null;
    return MemberLocation(latitude: latitude!, longitude: longitude!);
  }

  /// An empty pair means "no location". One filled cell, a non-number, or a
  /// value outside the geographic range is an error the user can fix.
  static MemberLocationParseResult parseText({
    required String latitudeText,
    required String longitudeText,
  }) {
    final latitudeRaw = latitudeText.trim();
    final longitudeRaw = longitudeText.trim();
    if (latitudeRaw.isEmpty && longitudeRaw.isEmpty) {
      return const MemberLocationParseResult();
    }
    if (latitudeRaw.isEmpty || longitudeRaw.isEmpty) {
      return const MemberLocationParseResult(
        error: 'أدخل خط العرض وخط الطول معًا، أو اتركهما فارغين',
      );
    }
    final latitude = _parseCoordinate(latitudeRaw);
    final longitude = _parseCoordinate(longitudeRaw);
    if (latitude == null || longitude == null) {
      return const MemberLocationParseResult(
        error: 'خط العرض أو خط الطول ليس رقمًا',
      );
    }
    if (latitude < -90 || latitude > 90) {
      return const MemberLocationParseResult(
        error: 'خط العرض يجب أن يكون بين -90 و 90',
      );
    }
    if (longitude < -180 || longitude > 180) {
      return const MemberLocationParseResult(
        error: 'خط الطول يجب أن يكون بين -180 و 180',
      );
    }
    return MemberLocationParseResult(
      location: MemberLocation(latitude: latitude, longitude: longitude),
    );
  }

  Uri get directionsUri => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
  });
}

class MemberLocationParseResult {
  final MemberLocation? location;
  final String? error;

  const MemberLocationParseResult({this.location, this.error});
}

/// Result of the map picker. A dismissed picker returns null instead.
class MemberLocationPick {
  final double? latitude;
  final double? longitude;

  const MemberLocationPick({this.latitude, this.longitude});

  const MemberLocationPick.cleared() : latitude = null, longitude = null;

  bool get hasLocation => latitude != null && longitude != null;
}

String formatMemberCoordinate(double value) {
  final text = value.toStringAsFixed(6);
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

bool _isInRange(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

double? _parseCoordinate(String value) {
  final compact = value.replaceAll(' ', '');
  final normalized = compact.contains('.')
      ? compact
      : compact.replaceFirst(',', '.');
  return double.tryParse(normalized);
}
