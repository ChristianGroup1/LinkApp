import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:link/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists the selected theme preference', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_preference': AppThemePreference.dark.name,
    });

    final controller = ThemeController.instance;
    await controller.load();

    expect(controller.preference, AppThemePreference.dark);
    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.resolvedBrightness, Brightness.dark);

    await controller.setPreference(AppThemePreference.light);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('app_theme_preference'),
      AppThemePreference.light.name,
    );
    expect(controller.themeMode, ThemeMode.light);

    await controller.setPreference(AppThemePreference.system);
  });

  test('falls back to the system theme for an unknown saved value', () async {
    SharedPreferences.setMockInitialValues({
      'app_theme_preference': 'unsupported',
    });

    final controller = ThemeController.instance;
    await controller.load();

    expect(controller.preference, AppThemePreference.system);
    expect(controller.themeMode, ThemeMode.system);
  });
}
