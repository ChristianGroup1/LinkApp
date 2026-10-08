import 'dart:io';

/// Widget tests have no reason to download map tiles.
bool get useLiveMemberMap => Platform.environment['FLUTTER_TEST'] != 'true';
