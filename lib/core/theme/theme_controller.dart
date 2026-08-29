import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  static AppThemePreference fromStoredValue(String? value) => switch (value) {
    'light' => AppThemePreference.light,
    'dark' => AppThemePreference.dark,
    _ => AppThemePreference.system,
  };
}

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static const _preferenceKey = 'app_theme_preference';
  static final ThemeController instance = ThemeController._();

  ThemeController._() {
    WidgetsBinding.instance.addObserver(this);
  }

  AppThemePreference _preference = AppThemePreference.system;

  AppThemePreference get preference => _preference;
  ThemeMode get themeMode => _preference.themeMode;

  Brightness get resolvedBrightness => switch (_preference) {
    AppThemePreference.light => Brightness.light,
    AppThemePreference.dark => Brightness.dark,
    AppThemePreference.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _preference = AppThemePreference.fromStoredValue(
      preferences.getString(_preferenceKey),
    );
    notifyListeners();
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, preference.name);
  }

  @override
  void didChangePlatformBrightness() {
    if (_preference == AppThemePreference.system) notifyListeners();
  }
}
